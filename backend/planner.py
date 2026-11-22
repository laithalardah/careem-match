"""Turns a shortlist into a basket. Two planners share everything in this file:

* the DETERMINISTIC planner (below): always works, no LLM. It walks the shortlist, verifies the restaurant
  is open, resolves required options to the cheapest choice, gives each person a dish and prices the basket.
  If a restaurant fails (closed, error, dish unavailable, options unresolvable) it re-plans to the next one.
* the Bedrock agent (agent.py) which uses the same Gateway, validator and basket builder, and falls back
  to this planner on any problem.

Only READ-ONLY MCP tools are used here. Lookups are retried (2 retries); nothing mutating is ever called.
"""
from __future__ import annotations

import asyncio
import logging
from collections import Counter
from dataclasses import dataclass, field

import config
import dispute
import rooms
from catalog import LOCATION, Dish, Option, OptionGroup, Restaurant, parse_menu
from rooms import Room

log = logging.getLogger("planner")
LOOKUP_RETRIES = 2
RETRY_PAUSE = 0.2


class LookupFailed(Exception):
    """A read-only lookup failed or returned an error message."""


class PlanFailed(Exception):
    """This restaurant cannot be ordered from; try the next one."""


# ── Trace ────────────────────────────────────────────────────────────────────
class Trace:
    def __init__(self, group_id: str):
        self.group_id = group_id
        self.steps: list[dict] = []

    def add(self, tool: str, inp: dict, summary: str, failed: bool = False) -> None:
        self.steps.append({
            "iteration": len(self.steps) + 1, "tool": tool, "input": inp,
            "output_summary": summary, "failed": failed, "group_id": self.group_id,
        })


# ── Gateways: read-only access to restaurant data ────────────────────────────
def _structured(r) -> dict:
    s = r.structured_content or {}
    if r.is_error:
        text = r.content[0].text if r.content else "tool error"
        raise LookupFailed(text)
    if s.get("error"):
        raise LookupFailed(str(s["error"]))
    return s


def _parse_option_groups(raw: list[dict]) -> list[OptionGroup]:
    return [
        OptionGroup(
            id=g["group_id"], name=g["name"], required=bool(g.get("required")), min=g.get("min", 0), max=g.get("max", 1),
            multi=bool(g.get("multi_select")),
            options=[Option(id=o["option_id"], group_id=g["group_id"], catalog_option_id=o["catalog_option_id"],
                            name=o["name"], price=float(o["price"])) for o in g.get("options", []) if o.get("is_active", True)],
        )
        for g in raw
    ]


class LiveGateway:
    """The Careem MCP (sandbox or production). One connection per plan."""

    cached = False

    async def __aenter__(self):
        from mcp_client import Careem

        self._c = Careem()
        await self._c.__aenter__()
        return self

    async def __aexit__(self, *exc):
        await self._c.__aexit__(*exc)

    async def menu(self, rid: int) -> Restaurant:
        s = _structured(await self._c.call("food_get_restaurant_menu", {"restaurant_id": rid, **LOCATION}))
        if not s.get("restaurant"):
            raise LookupFailed("restaurant not found")
        return parse_menu(s["restaurant"])

    async def options(self, rid: int, item_ids: list[str]) -> dict[str, list[OptionGroup]]:
        s = _structured(await self._c.call(
            "food_get_items_options", {"restaurant_id": rid, "item_ids": [int(i) for i in item_ids], **LOCATION}))
        out = {}
        for item in s.get("results", []):
            if item.get("error"):
                raise LookupFailed(f"item {item.get('item_id')}: {item['error']}")
            out[str(item["item_id"])] = _parse_option_groups(item.get("option_groups", []))
        return out


class CacheGateway:
    """FALLBACK=1: answers from the cached catalog, no MCP calls."""

    cached = True

    def __init__(self, catalog):
        self.catalog = catalog

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return None

    async def menu(self, rid: int) -> Restaurant:
        r = self.catalog.by_id(rid)
        if not r:
            raise LookupFailed("restaurant not found")
        return r

    async def options(self, rid: int, item_ids: list[str]) -> dict[str, list[OptionGroup]]:
        r = await self.menu(rid)
        return {d.id: d.option_groups for d in r.dishes if d.id in item_ids}


def make_gateway(room: Room):
    return CacheGateway(room.catalog) if config.fallback_mode() else LiveGateway()


async def lookup(trace: Trace, cached: bool, tool: str, inp: dict, fn, summarize):
    """One read-only lookup with retries. Records every attempt in the trace. Raises LookupFailed."""
    label = f"cache:{tool}" if cached else tool
    last = "unknown error"
    for attempt in range(LOOKUP_RETRIES + 1):
        try:
            result = await fn()
            trace.add(label, inp, summarize(result))
            return result
        except LookupFailed as e:
            last = str(e)
        except Exception as e:  # noqa: BLE001  (network hiccups etc.)
            last = f"{type(e).__name__}: {e}"
        retry = attempt < LOOKUP_RETRIES
        trace.add(label, inp, f"Failed: {last}." + (" Retrying." if retry else " Giving up on this restaurant."), failed=True)
        if retry:
            await asyncio.sleep(RETRY_PAUSE)
    raise LookupFailed(last)


# ── Plans ────────────────────────────────────────────────────────────────────
@dataclass
class PlanLine:
    participant_id: str
    dish: Dish
    options: list[Option] = field(default_factory=list)

    @property
    def price(self) -> float:
        return round(self.dish.price + sum(o.price for o in self.options), 2)


@dataclass
class Plan:
    restaurant: Restaurant
    lines: list[PlanLine]
    reasoning: str
    per_person: list[dict]
    source: str = "planner"  # "planner" | "agent"


def cheapest_required_options(dish: Dish, groups: list[OptionGroup]) -> list[Option]:
    """Required groups get their cheapest active options (as many as `min`). Raises PlanFailed if impossible."""
    chosen: list[Option] = []
    for g in groups:
        need = g.min if g.required else 0
        if need == 0:
            continue
        opts = sorted(g.options, key=lambda o: o.price)
        if len(opts) < need:
            raise PlanFailed(f"'{dish.name}' needs {need} choice(s) in '{g.name}' but none are available")
        chosen += opts[:need]
    return chosen


def validate_options(dish: Dish, groups: list[OptionGroup], chosen: list[Option]) -> None:
    """Every required group satisfied, no group over its max, every option belongs to the dish."""
    by_group = Counter(o.group_id for o in chosen)
    valid = {o.catalog_option_id for g in groups for o in g.options}
    for o in chosen:
        if o.catalog_option_id not in valid:
            raise PlanFailed(f"option {o.catalog_option_id} does not belong to '{dish.name}'")
    for g in groups:
        n = by_group.get(g.id, 0)
        if g.required and n < g.min:
            raise PlanFailed(f"'{dish.name}' needs a choice in '{g.name}'")
        if n > max(g.max, 1 if g.required else 0):
            raise PlanFailed(f"too many choices in '{g.name}' for '{dish.name}'")


def orderable(dish: Dish) -> bool:
    """False when a required option group has fewer active choices than it needs."""
    return all(len(g.options) >= g.min for g in dish.option_groups if g.required)


def history_items(room: Room, pid: str) -> set[str]:
    h = room.history.get(pid)
    return {i.lower() for o in (h.orders if h else []) for i in o.get("items", [])}


def choose_dishes(room: Room, rest: Restaurant, pids: list[str]) -> list[tuple[str, Dish]]:
    """One dish each: prefer something they ordered before, then variety across the group."""
    active = [d for d in rest.dishes if d.active and orderable(d)]
    if not active:
        raise PlanFailed(f"{rest.name} has no dishes that can be ordered right now")
    used: Counter = Counter()
    out = []
    for pid in pids:
        ordered_before = history_items(room, pid)
        best = max(active, key=lambda d: (2 if d.name.lower() in ordered_before else 0) + (1 if used[d.id] == 0 else 0))
        used[best.id] += 1
        out.append((pid, best))
    return out


# ── Explanations (facts only) ────────────────────────────────────────────────
def _names(room: Room, pids: list[str]) -> str:
    names = [room.participants[p].name for p in pids]
    return names[0] if len(names) == 1 else ", ".join(names[:-1]) + " and " + names[-1]


def why_for(room: Room, pid: str, rest: Restaurant, dish: Dish | None) -> str:
    sig = dispute.signals(room)
    parts = []
    if dish:
        parts.append(f"Gets {dish.name}.")
    s = sig.swipe_r.get(pid, {}).get(rest.id, 0)
    if s == 1:
        parts.append(f"You liked {rest.name}.")
    elif s == -1:
        parts.append(f"You skipped {rest.name}, but it worked best for the group.")
    elif sig.swipe_c.get(pid, {}).get(rest.category, 0) == 1:
        parts.append(f"You liked {rest.category}.")
    if dish and dish.name.lower() in history_items(room, pid):
        parts.append("You have ordered it before.")
    return " ".join(parts)


def group_reasoning(room: Room, rest: Restaurant, group: dict, resolution: str) -> str:
    pids = group["participant_ids"]
    if resolution == "wheel":
        return f"The wheel picked {rest.name}, so one order covers everyone."
    if resolution == "split":
        return f"{_names(room, pids)} chose {rest.name}, so they get their own order."
    sig = dispute.signals(room)
    likes = sum(1 for p in pids if sig.swipe_r.get(p, {}).get(rest.id, 0) == 1)
    if group.get("compromise") or likes < len(pids) * config.consensus_threshold():
        return f"{rest.name} is the best compromise: no place won everyone, and nobody vetoed it."
    return f"{rest.name} was liked by {likes} of {len(pids)} and nobody vetoed it, so one order covers everyone."


# ── Deterministic planner ────────────────────────────────────────────────────
async def plan_restaurant(room: Room, gw, rid: int, group: dict, trace: Trace, resolution: str) -> Plan:
    """Plan one restaurant. Raises PlanFailed / LookupFailed when it cannot be ordered from."""
    pids = group["participant_ids"]
    rest = await lookup(trace, gw.cached, "food_get_restaurant_menu", {"restaurant_id": rid},
                        lambda: gw.menu(rid), lambda r: f"{r.name}: {'open' if r.available else 'CLOSED'}, {len([d for d in r.dishes if d.active])} dishes.")
    if not rest.available:
        trace.steps[-1].update(failed=True, output_summary=f"{rest.name} is closed right now. Trying the next choice.")
        raise PlanFailed(f"{rest.name} is closed")
    if room.mode == "dineout":
        return Plan(rest, [], group_reasoning(room, rest, group, resolution),
                    [{"participant_id": p, "name": room.participants[p].name, "why": why_for(room, p, rest, None)} for p in pids])

    picks = choose_dishes(room, rest, pids)
    need = sorted({d.id for _, d in picks if d.requires_options})
    groups_by_item: dict[str, list[OptionGroup]] = {d.id: d.option_groups for _, d in picks}
    if need:
        try:
            got = await lookup(trace, gw.cached, "food_get_items_options", {"restaurant_id": rid, "item_ids": need},
                               lambda: gw.options(rid, need), lambda r: f"Option groups for {len(r)} item(s).")
            groups_by_item.update(got)
        except LookupFailed:
            trace.add("plan", {"restaurant_id": rid}, "Options lookup kept failing; using the option data from the menu.")
    lines = []
    for pid, dish in picks:
        opts = cheapest_required_options(dish, groups_by_item.get(dish.id, dish.option_groups))
        validate_options(dish, groups_by_item.get(dish.id, dish.option_groups), opts)
        lines.append(PlanLine(pid, dish, opts))
    trace.add("plan", {"restaurant_id": rid, "people": len(pids)},
              "Dishes: " + "; ".join(f"{room.participants[l.participant_id].name}: {l.dish.name}" for l in lines)
              + ". Required options set to the cheapest choice.")
    return Plan(rest, lines, group_reasoning(room, rest, group, resolution),
                [{"participant_id": l.participant_id, "name": room.participants[l.participant_id].name,
                  "why": why_for(room, l.participant_id, rest, l.dish)} for l in lines])


async def plan_deterministic(room: Room, gw, group: dict, trace: Trace, resolution: str) -> Plan:
    last = "no restaurant could be ordered from"
    for n, rid in enumerate(group["shortlist"]):
        try:
            return await plan_restaurant(room, gw, rid, group, trace, resolution)
        except (PlanFailed, LookupFailed) as e:
            last = str(e)
            if n + 1 < len(group["shortlist"]):
                trace.add("replan", {"failed_restaurant_id": rid}, f"{e}. Re-planning with the next shortlisted restaurant.")
    raise PlanFailed(last)


# ── Result assembly ──────────────────────────────────────────────────────────
def group_payload(room: Room, group_id: str, plan: Plan, group: dict) -> dict:
    r = plan.restaurant
    basket = [
        {"participant_id": l.participant_id, "name": room.participants[l.participant_id].name, "dish_name": l.dish.name,
         "price": l.price, "image_url": l.dish.image_url, "options": [o.name for o in l.options]}
        for l in plan.lines
    ]
    return {
        "group_id": group_id,
        "restaurant": {"id": r.id, "name": r.name, "image_url": r.image_url, "cuisine": r.category, "rating": r.rating, "link": r.link},
        "participant_ids": list(group["participant_ids"]), "basket": basket,
        "total_price": round(sum(b["price"] for b in basket), 2), "currency": r.currency,
        "reasoning": plan.reasoning, "per_person": plan.per_person,
    }


async def plan_one(room: Room, group: dict, group_id: str, resolution: str) -> tuple[dict | None, Trace, str | None]:
    """Plan one group: Bedrock agent first (if enabled), deterministic planner as the safety net."""
    trace = Trace(group_id)
    try:
        async with (GATEWAY_FACTORY or make_gateway)(room) as gw:
            plan = None
            if config.agent_mode() == "bedrock" and room.mode == "food":
                import agent

                try:
                    plan = await agent.plan_with_agent(room, gw, group, trace, resolution)
                except Exception as e:  # noqa: BLE001
                    log.warning("agent failed for room %s: %s: %s", room.code, type(e).__name__, e)
                    hint = " (credentials expired: run refresh_env.ps1)" if agent.is_expired_credentials(e) else ""
                    trace.add("agent", {}, f"Bedrock agent unavailable{hint}: {type(e).__name__}. Using the deterministic planner.", failed=True)
            if plan is None:
                plan = await plan_deterministic(room, gw, group, trace, resolution)
            room.plans[group_id] = plan
            return group_payload(room, group_id, plan, group), trace, None
    except (PlanFailed, LookupFailed) as e:
        return None, trace, str(e)


GATEWAY_FACTORY = None  # tests replace this with a fake gateway factory


async def run_groups(room: Room, groups: list[dict], resolution: str) -> None:
    room.plans = {}
    outcomes = await asyncio.gather(*[plan_one(room, g, f"g{i + 1}", resolution) for i, g in enumerate(groups)])
    trace = [s for _, t, _ in outcomes for s in t.steps]
    scores = room.result["scores"] if room.result else []
    done = [o[0] for o in outcomes if o[0]]
    if not done:
        reason = "; ".join(sorted({o[2] for o in outcomes if o[2]})) or "nothing could be ordered"
        res = {**rooms.empty_result("failed", f"No restaurant could be ordered from: {reason}.", resolution), "scores": scores, "agent_trace": trace}
    else:
        res = {**rooms.empty_result("ready", resolution=resolution), "groups": done, "scores": scores, "agent_trace": trace}
        if len(outcomes) > len(done):  # some group failed: say so, keep the others
            res["reasoning"] = "One group could not be matched; the others are ready."
        if len(done) == 1 and len(groups) == 1:
            first = done[0]
            res.update({k: first[k] for k in ("restaurant", "basket", "total_price", "currency", "reasoning", "per_person")})
    room.result = res
    room.stage = "result"
    room.touch()
