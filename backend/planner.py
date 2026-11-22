"""Turns a shortlist into the restaurant the group goes to. No dishes, no basket: after the match everyone is
sent to the restaurant to do Careem's normal group order themselves.

Two planners share everything in this file:
* the DETERMINISTIC planner (below): always works, no LLM. It walks the shortlist and takes the first restaurant that
  is open and has something to order. If one fails (closed, lookup error, nothing orderable) it re-plans to the next.
* the Bedrock agent (agent.py): same Gateway and validator, falls back to this planner on any problem.

Only READ-ONLY MCP lookups are used, and they are retried (2 retries). Nothing in this project changes an order.
"""
from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass

import config
import dispute
import rooms
from catalog import LOCATION, Restaurant, parse_menu
from rooms import Room

log = logging.getLogger("planner")
LOOKUP_RETRIES = 2
RETRY_PAUSE = 0.2


class LookupFailed(Exception):
    """A read-only lookup failed or returned an error message."""


class PlanFailed(Exception):
    """This restaurant cannot be used; try the next one."""


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


def menu_summary(r: Restaurant) -> str:
    return f"{r.name}: {'open' if r.available else 'CLOSED'}, {len([d for d in r.dishes if d.active])} dishes."


def check_orderable(rest: Restaurant) -> None:
    """The restaurant must be open and have something on the menu, or the group could not order there."""
    if not rest.available:
        raise PlanFailed(f"{rest.name} is closed")
    if not any(d.active for d in rest.dishes):
        raise PlanFailed(f"{rest.name} has nothing to order right now")


# ── Plans ────────────────────────────────────────────────────────────────────
@dataclass
class Plan:
    restaurant: Restaurant
    reasoning: str
    per_person: list[dict]
    source: str = "planner"  # "planner" | "agent"


# ── Explanations (facts only) ────────────────────────────────────────────────
def _names(room: Room, pids: list[str]) -> str:
    names = [room.participants[p].name for p in pids]
    return names[0] if len(names) == 1 else ", ".join(names[:-1]) + " and " + names[-1]


def why_for(room: Room, pid: str, rest: Restaurant) -> str:
    """Why this restaurant suits this person, from their own votes and history only."""
    sig = dispute.signals(room)
    parts = []
    s = sig.swipe_r.get(pid, {}).get(rest.id, 0)
    if s == 1:
        parts.append(f"You liked {rest.name}.")
    elif s == -1:
        parts.append(f"You skipped {rest.name}, but it worked best for the group.")
    elif sig.swipe_c.get(pid, {}).get(rest.category, 0) == 1:
        parts.append(f"You liked {rest.category}.")
    h = room.history.get(pid)
    if h and h.restaurant.get(rest.id, 0) > 0:
        parts.append("You have ordered here before.")
    return " ".join(parts) or f"{rest.name} fits what the group picked."


def per_person(room: Room, pids: list[str], rest: Restaurant) -> list[dict]:
    return [{"participant_id": p, "name": room.participants[p].name, "why": why_for(room, p, rest)} for p in pids]


def group_reasoning(room: Room, rest: Restaurant, group: dict, resolution: str) -> str:
    pids = group["participant_ids"]
    if resolution == "wheel":
        return f"The wheel picked {rest.name}, so everyone orders from there."
    if resolution == "split":
        return f"{_names(room, pids)} chose {rest.name}, so they order from there together."
    sig = dispute.signals(room)
    likes = sum(1 for p in pids if sig.swipe_r.get(p, {}).get(rest.id, 0) == 1)
    if group.get("compromise") or likes < len(pids) * config.consensus_threshold():
        return f"{rest.name} is the best compromise: no place won everyone, and nobody vetoed it."
    return f"{rest.name} was liked by {likes} of {len(pids)} and nobody vetoed it, so the whole group can order from one place."


# ── Deterministic planner ────────────────────────────────────────────────────
async def plan_restaurant(room: Room, gw, rid: int, group: dict, trace: Trace, resolution: str) -> Plan:
    """Check one restaurant. Raises PlanFailed / LookupFailed when the group cannot use it."""
    rest = await lookup(trace, gw.cached, "food_get_restaurant_menu", {"restaurant_id": rid},
                        lambda: gw.menu(rid), menu_summary)
    try:
        check_orderable(rest)
    except PlanFailed as e:
        trace.steps[-1].update(failed=True, output_summary=f"{e}. Trying the next choice.")
        raise
    return Plan(rest, group_reasoning(room, rest, group, resolution), per_person(room, group["participant_ids"], rest))


async def plan_deterministic(room: Room, gw, group: dict, trace: Trace, resolution: str) -> Plan:
    last = "no restaurant could be used"
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
    return {
        "group_id": group_id,
        "restaurant": {"id": r.id, "name": r.name, "image_url": r.image_url, "cuisine": r.category, "rating": r.rating, "link": r.link},
        "participant_ids": list(group["participant_ids"]),
        # No dishes or prices: everyone picks their own in Careem's group order.
        "basket": [], "total_price": 0, "currency": r.currency,
        "reasoning": plan.reasoning, "per_person": plan.per_person,
    }


async def plan_one(room: Room, group: dict, group_id: str, resolution: str) -> tuple[dict | None, Trace, str | None]:
    """Choose the restaurant for one group: Bedrock agent first (if enabled), deterministic planner as the safety net."""
    trace = Trace(group_id)
    try:
        async with (GATEWAY_FACTORY or make_gateway)(room) as gw:
            # Handle every failure INSIDE the block: the MCP session wraps exceptions that leave it in an
            # unreadable ExceptionGroup, and we would lose the trace.
            try:
                plan = None
                if config.agent_mode() == "bedrock":
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
            except Exception as e:  # noqa: BLE001
                log.exception("planning crashed for room %s", room.code)
                return None, trace, f"unexpected error ({type(e).__name__})"
    except Exception as e:  # noqa: BLE001  (could not even open the connection)
        log.warning("gateway failed for room %s: %s: %s", room.code, type(e).__name__, e)
        trace.add("connect", {}, f"Could not reach the restaurant data service ({type(e).__name__}).", failed=True)
        return None, trace, "the restaurant data service is unreachable"


GATEWAY_FACTORY = None  # tests replace this with a fake gateway factory


async def run_groups(room: Room, groups: list[dict], resolution: str) -> None:
    room.plans = {}
    outcomes = await asyncio.gather(*[plan_one(room, g, f"g{i + 1}", resolution) for i, g in enumerate(groups)])
    trace = [s for _, t, _ in outcomes for s in t.steps]
    scores = room.result["scores"] if room.result else []
    done = [o[0] for o in outcomes if o[0]]
    if not done:
        reason = "; ".join(sorted({o[2] for o in outcomes if o[2]})) or "nothing could be used"
        res = {**rooms.empty_result("failed", f"No restaurant could be used: {reason}.", resolution), "scores": scores, "agent_trace": trace}
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
