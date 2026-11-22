"""Order history per participant, as weights the matching can use.

IMPORTANT: the Careem MCP is single-user. `get_activities` only returns the authenticated user's orders,
so history is REAL for the host only. Demo friends (bots) get seeded histories (source "demo"); real
guests have none (source "none") and their swipes dominate. In production each participant would sign in
(OAuth) and we would call the MCP with their own token.

    python history.py --refresh     # cache the host's history to fallback_history.json
"""
from __future__ import annotations

import asyncio
import json
import logging
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

import config
from catalog import Catalog

log = logging.getLogger("history")
CACHE_PATH = Path(__file__).parent / "fallback_history.json"
HALF_LIFE_DAYS = 30.0
MAX_PAGES = 5


@dataclass
class History:
    source: str = "none"  # "mcp" | "cache" | "demo" | "none"
    orders: list[dict] = field(default_factory=list)  # {restaurant_id, restaurant_name, days_ago, items:[str]}
    restaurant: dict[int, float] = field(default_factory=dict)  # 0..1
    category: dict[str, float] = field(default_factory=dict)  # 0..1

    def summary(self) -> dict:
        """Compact, JSON-safe evidence for the agent and the trace."""
        return {
            "source": self.source,
            "orders": [
                {"restaurant": o["restaurant_name"], "days_ago": round(o["days_ago"]), "items": o["items"][:4]}
                for o in self.orders[:5]
            ],
            "favourite_categories": [c for c, _ in sorted(self.category.items(), key=lambda kv: -kv[1])[:3]],
        }


def _normalise(d: dict) -> dict:
    top = max(d.values(), default=0)
    return {k: v / top for k, v in d.items()} if top > 0 else {}


def weigh(orders: list[dict], catalog: Catalog, source: str) -> History:
    """Recency-weighted counts (0.5^(age_days/30)), normalised so the strongest signal is 1."""
    r_w: dict[int, float] = {}
    c_w: dict[str, float] = {}
    for o in orders:
        w = 0.5 ** (max(o["days_ago"], 0) / HALF_LIFE_DAYS)
        rid = int(o["restaurant_id"])
        r_w[rid] = r_w.get(rid, 0) + w
        rest = catalog.by_id(rid)
        if rest:
            c_w[rest.category] = c_w.get(rest.category, 0) + w
    return History(source=source, orders=orders, restaurant=_normalise(r_w), category=_normalise(c_w))


def parse_activities(acts: list[dict], now: datetime | None = None) -> list[dict]:
    now = now or datetime.now(timezone.utc)
    out = []
    for a in acts:
        d = a.get("data") or {}
        if a.get("type") != "food" or not d.get("merchant_id"):
            continue
        try:
            when = datetime.fromisoformat(str(a.get("created_at")).replace("Z", "+00:00"))
            days = max((now - when).total_seconds() / 86400, 0)
        except ValueError:
            days = 30.0
        out.append({
            "restaurant_id": int(d["merchant_id"]), "restaurant_name": d.get("merchant_name", ""),
            "days_ago": days, "items": [i.get("name", "") for i in d.get("items", [])],
        })
    return out


async def fetch_host_orders() -> list[dict]:
    from mcp_client import Careem

    orders: list[dict] = []
    async with Careem() as c:
        cursor = None
        for _ in range(MAX_PAGES):
            args = {"activity_type": "food", "activity_status": "past"}
            if cursor:
                args["next_cursor"] = cursor
            r = await c.call("get_activities", args)
            s = r.structured_content or {}
            orders += parse_activities(s.get("past_activities") or [])
            paging = s.get("paging") or {}
            if not paging.get("has_next"):
                break
            cursor = paging["next_cursor"]
    return orders


def _cache_orders() -> list[dict]:
    try:
        return json.loads(CACHE_PATH.read_text(encoding="utf-8"))["orders"]
    except (OSError, ValueError, KeyError):
        return []


async def host_history(catalog: Catalog) -> History:
    if config.fallback_mode():
        return weigh(_cache_orders(), catalog, "cache")
    try:
        return weigh(await asyncio.wait_for(fetch_host_orders(), timeout=15), catalog, "mcp")
    except Exception as e:  # noqa: BLE001
        log.warning("host history failed (%s: %s); using cache", type(e).__name__, e)
        return weigh(_cache_orders(), catalog, "cache")


def bot_history(persona: dict, catalog: Catalog) -> History:
    """Seeded and deterministic: a couple of past orders in each loved category."""
    orders = []
    for i, cat in enumerate(persona.get("loves", [])):
        for j, rest in enumerate([r for r in catalog.restaurants if r.category == cat][:2]):
            orders.append({
                "restaurant_id": rest.id, "restaurant_name": rest.name,
                "days_ago": 4 + 9 * i + 11 * j, "items": [d.name for d in rest.dishes[:1]],
            })
    return weigh(orders, catalog, "demo")


async def for_room(room, catalog: Catalog) -> dict[str, History]:
    """History for every participant. Host: real. Bots: seeded demo. Real guests: none."""
    out: dict[str, History] = {}
    for p in room.participants.values():
        if p.is_bot:
            out[p.id] = bot_history(p.persona or {}, catalog)
        elif p.is_host:
            out[p.id] = await host_history(catalog)
        else:
            out[p.id] = History(source="none")
    return out


def group_prior(histories: dict[str, History]) -> dict:
    """Average history across the group: used to order the cards (likely favourites first)."""
    n = max(len(histories), 1)
    cat: dict[str, float] = {}
    rest: dict[int, float] = {}
    for h in histories.values():
        for k, v in h.category.items():
            cat[k] = cat.get(k, 0) + v / n
        for k, v in h.restaurant.items():
            rest[k] = rest.get(k, 0) + v / n
    return {"category": cat, "restaurant": rest}


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    if "--refresh" in sys.argv:
        orders = asyncio.run(fetch_host_orders())
        CACHE_PATH.write_text(json.dumps({"orders": orders}, indent=1, ensure_ascii=False), encoding="utf-8")
        print(f"{len(orders)} past food orders cached -> {CACHE_PATH.name}")
        for o in orders:
            print(f"  {o['restaurant_name']:<24} {o['days_ago']:.0f} days ago  {o['items']}")
    else:
        print("usage: python history.py --refresh")
