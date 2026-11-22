"""Group order: the host's tap on "Create group order" is the ONLY approval for the one mutating step.

Food mode: for each group, ONE `cart_add_items` call for that merchant (every line commented "for NAME"),
then a read-only price lookup. NEVER checks out: no checkout / order-placing tool is used anywhere.
Safety:
  * only tools in ALLOWED_MUTATIONS can be called with mutation allowed
  * no automatic retry. If a call times out or breaks mid-way the outcome is unknown, so we say so and let
    the host decide (a blind retry could add everything twice)
  * a retry by the host only re-adds the lines that failed, never the ones already in the basket
FALLBACK=1 (or no MCP): nothing is sent to Careem, the basket is only simulated and labelled as such.
Dine out: no cart at all, just the restaurant link.
"""
from __future__ import annotations

import asyncio
import logging

import config
import rooms
from catalog import LOCATION
from rooms import ApiError, Room

log = logging.getLogger("order")
ALLOWED_MUTATIONS = {"cart_add_items"}  # deliberately NOT checkout
CALL_TIMEOUT = 20.0


class AddUnknown(Exception):
    """The add call may or may not have reached Careem."""


class LiveCart:
    cached = False

    async def __aenter__(self):
        from mcp_client import Careem

        self._c = Careem()
        await self._c.__aenter__()
        return self

    async def __aexit__(self, *exc):
        await self._c.__aexit__(*exc)

    async def add_items(self, merchant_id: int, items: list[dict]) -> list[dict]:
        name = "cart_add_items"
        assert name in ALLOWED_MUTATIONS
        try:
            r = await asyncio.wait_for(
                self._c.call(name, {"merchant_id": merchant_id, "domain": "food", "items": items, **LOCATION}, allow_mutating=True),
                CALL_TIMEOUT)
        except Exception as e:  # noqa: BLE001  (timeout, dropped connection...)
            raise AddUnknown(f"{type(e).__name__}") from e
        s = r.structured_content or {}
        if r.is_error or s.get("error"):
            text = s.get("error") or (r.content[0].text if r.content else "error")
            return [{"success": False, "error": str(text)} for _ in items]  # the call itself was refused: nothing added
        return s.get("results", [])

    async def price(self, merchant_id: int) -> dict:
        r = await self._c.call("cart_get_basket_price", {"merchant_id": merchant_id, "domain": "food", **LOCATION})
        s = r.structured_content or {}
        if r.is_error or s.get("error"):
            raise RuntimeError(s.get("error") or "price unavailable")
        return s


class SimulatedCart:
    """FALLBACK=1: nothing is sent anywhere."""

    cached = True

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return None


CART_FACTORY = None  # tests replace this


def make_cart():
    return SimulatedCart() if config.fallback_mode() else LiveCart()


# ── Building the request ─────────────────────────────────────────────────────
def cart_items(room: Room, plan, indexes: list[int]) -> list[dict]:
    out = []
    for i in indexes:
        line = plan.lines[i]
        out.append({
            "catalog_item_id": line.dish.id, "count": 1,
            "comment": f"for {room.participants[line.participant_id].name}",
            "options": [{"catalog_option_id": o.catalog_option_id, "count": 1} for o in line.options],
        })
    return out


def breakdown_from_price(s: dict, currency: str) -> dict:
    p = s.get("price", {})
    lines = []
    for row in p.get("breakdown", []):
        vals = row.get("value") or [{}]
        lines.append({"label": row.get("label", {}).get("title", ""), "amount": vals[0].get("price")})
    return {"currency": currency, "lines": lines, "total": (p.get("price") or {}).get("total")}


def estimate(plan, currency: str) -> dict:
    total = round(sum(l.price for l in plan.lines), 2)
    return {"currency": currency, "lines": [{"label": "Subtotal (estimate)", "amount": total}], "total": total}


# ── The order ────────────────────────────────────────────────────────────────
async def create_orders(room: Room, pid: str) -> dict:
    rooms.require_host(room, pid)
    if room.stage == "ordered" and room.order:
        return room.order  # idempotent: a second tap changes nothing
    rooms.require_stage(room, "result")
    if not room.result or room.result.get("status") != "ready" or not room.result.get("groups"):
        raise ApiError(409, "There is nothing to order yet.")

    groups = room.result["groups"]
    state = room.order_state  # group_id -> {"added": set(line index), ...}
    outcomes: list[dict] = []

    if room.mode == "dineout":
        outcomes = [{"group_id": g["group_id"], "status": "go", "price_breakdown": None,
                     "restaurant_link": g["restaurant"]["link"],
                     "message": f"Head to {g['restaurant']['name']}. Nothing was ordered."} for g in groups]
    else:
        try:
            async with (CART_FACTORY or make_cart)() as cart:
                for g in groups:
                    outcomes.append(await _order_group(room, cart, g, state.setdefault(g["group_id"], {"added": set()})))
        except Exception as e:  # noqa: BLE001  (e.g. could not connect: nothing was sent, safe to try again)
            log.warning("order failed for %s: %s: %s", room.code, type(e).__name__, e)
            done = {o["group_id"] for o in outcomes}
            outcomes += [{"group_id": g["group_id"], "status": "failed", "price_breakdown": None, "restaurant_link": g["restaurant"]["link"],
                          "message": f"Could not reach Careem ({type(e).__name__}). Nothing was changed; you can try again."}
                         for g in groups if g["group_id"] not in done]

    ok = all(o["status"] in ("basket_ready", "go") for o in outcomes)
    status = "go" if room.mode == "dineout" else ("basket_ready" if ok else "failed")
    room.order = {
        "status": status, "groups": outcomes,
        "message": "Your group order is ready in the Careem app. Nothing has been paid." if status == "basket_ready"
        else ("Go to the restaurant." if status == "go" else "Some baskets could not be created. See the details and try again."),
    }
    if ok:
        room.stage = "ordered"
    room.touch()
    return room.order


async def _order_group(room: Room, cart, g: dict, st: dict) -> dict:
    plan = room.plans[g["group_id"]]
    link, currency = g["restaurant"]["link"], g["currency"]
    base = {"group_id": g["group_id"], "restaurant_link": link}
    todo = [i for i in range(len(plan.lines)) if i not in st["added"]]

    if getattr(cart, "cached", False):  # simulated
        st["added"] = set(range(len(plan.lines)))
        return {**base, "status": "basket_ready", "price_breakdown": estimate(plan, currency),
                "message": "Cached mode: nothing was sent to Careem. This basket is only an estimate."}

    if todo:
        try:
            results = await cart.add_items(plan.restaurant.id, cart_items(room, plan, todo))
        except AddUnknown as e:
            log.error("cart_add_items outcome unknown for %s: %s", room.code, e)
            return {**base, "status": "failed", "price_breakdown": None,
                    "message": f"We could not confirm the order was added ({e}). Check your basket in the Careem app before trying again, so nothing is added twice."}
        added, failed, unverified = match_results(plan, todo, results)
        st["added"] |= added
        if unverified and config.sandbox_mcp() and any(r.get("success") for r in results):
            # The sandbox answers with fixed test data instead of echoing our items. Accept, but say so.
            st["added"] |= unverified
            unverified = set()
            note = " (Sandbox answered with fixed test data, so the items could not be verified.)"
        else:
            note = ""
        failed += [f"{plan.lines[i].dish.name} (Careem did not confirm it)" for i in sorted(unverified)]
        if failed:
            return {**base, "status": "failed", "price_breakdown": None,
                    "message": "These could not be added: " + "; ".join(failed)
                    + ". Check your basket in the Careem app. Trying again only adds what is missing."}
    else:
        note = ""

    try:
        if config.sandbox_mcp():
            # The sandbox's price lookup is fixed test data that does not match our items, so show our own estimate.
            breakdown = estimate(plan, currency)
            msg = f"Basket created at {plan.restaurant.name}. Not paid. (Sandbox prices are fixed test data; this is the estimate from menu prices.)"
        else:
            breakdown = breakdown_from_price(await cart.price(plan.restaurant.id), currency)
            msg = f"Basket created at {plan.restaurant.name}. Not paid."
    except Exception as e:  # noqa: BLE001  (price is a read; the basket itself is fine)
        breakdown = estimate(plan, currency)
        msg = f"Basket created at {plan.restaurant.name}, but the final price could not be read ({type(e).__name__}); showing an estimate."
    return {**base, "status": "basket_ready", "price_breakdown": breakdown, "message": msg + note}


def match_results(plan, todo: list[int], results: list[dict]) -> tuple[set[int], list[str], set[int]]:
    """Pair each requested line with Careem's answer for the same catalog_item_id (each answer used once).
    Returns (added line indexes, failure texts, lines Careem gave no answer for)."""
    pool = list(results)
    added: set[int] = set()
    failed: list[str] = []
    unverified: set[int] = set()
    for idx in todo:
        item_id = plan.lines[idx].dish.id
        k = next((j for j, r in enumerate(pool) if str(r.get("catalog_item_id")) == item_id), None)
        if k is None:
            unverified.add(idx)
            continue
        r = pool.pop(k)
        if r.get("success"):
            added.add(idx)
        else:
            failed.append(f"{plan.lines[idx].dish.name} ({r.get('error') or r.get('message') or 'not available'})")
    # answers without ids (refused call): same order as the request
    if unverified and all("catalog_item_id" not in r for r in results) and len(results) == len(todo):
        by_pos = dict(zip(todo, results))
        for idx in sorted(unverified):
            r = by_pos[idx]
            if r.get("success"):
                added.add(idx)
            else:
                failed.append(f"{plan.lines[idx].dish.name} ({r.get('error') or r.get('message') or 'not available'})")
        unverified = set()
    return added, failed, unverified
