"""Bedrock agent: picks the restaurant from the shortlist and builds the basket with tool use.

Converse API, model global.anthropic.claude-sonnet-5-5 (us-east-1), at most MAX_ITERATIONS model calls.
The model only sees READ-ONLY tools (menu, item options) plus `submit_plan`. Everything it submits is
re-checked by code (validate): wrong restaurant, unknown dish, missing person or missing required option
are rejected, and prices are recomputed from the menu. On any problem planner.py takes over.
"""
from __future__ import annotations

import asyncio
import json
import logging
import time

import bedrock_client
import dispute
import scoring
from catalog import Option, Restaurant
from planner import LookupFailed, Plan, PlanFailed, PlanLine, Trace, _parse_option_groups, group_reasoning, lookup, validate_options, why_for
from rooms import Room

log = logging.getLogger("agent")
MAX_ITERATIONS = 8
EXPIRED_CODES = {"ExpiredTokenException", "ExpiredToken", "UnrecognizedClientException", "InvalidSignatureException", "InvalidClientTokenId"}

SYSTEM = """You are the ordering agent of Careem Match. A group of friends swiped on restaurants; you turn the shortlist into ONE food order.

Rules you must follow:
- Choose the restaurant ONLY from the shortlist. If the group already decided (a single restaurant on the shortlist), use it.
- Prefer a restaurant liked by most people with nobody vetoing it. Never pick a vetoed restaurant unless nothing else works.
- Call get_restaurant_menu to check the restaurant is open and see its dishes. If it is closed or the call fails, move to the next shortlisted restaurant (re-plan).
- Call get_item_options for dishes that need options. Every required option group must get its minimum number of choices. Prefer the cheapest choice unless a person's history suggests otherwise.
- Give each person 1 or 2 dishes. Prefer dishes they ordered before (see their history) and keep the order sensible and varied.
- Use only ids you were given. Never invent restaurants, dishes, options or prices.
- Finish by calling submit_plan exactly once. The reasoning must be ONE short sentence that is true given the data. Each person's `why` is one short sentence.
- You can only look things up. You never place an order, add to a cart, or pay: a human host approves the order later.
- Tool errors are readable messages. Explain them to yourself and decide whether to try another restaurant.
- Location is Amman, Jordan. Use the currency the data shows. Do not convert prices."""

TOOLS = [
    {"toolSpec": {
        "name": "get_restaurant_menu",
        "description": "Read-only. Is the restaurant open, and what dishes (id, name, price, requires_options) does it have?",
        "inputSchema": {"json": {"type": "object", "properties": {"restaurant_id": {"type": "integer"}}, "required": ["restaurant_id"]}},
    }},
    {"toolSpec": {
        "name": "get_item_options",
        "description": "Read-only. Option groups (required or optional) with option ids and prices for dishes of one restaurant.",
        "inputSchema": {"json": {"type": "object", "properties": {
            "restaurant_id": {"type": "integer"}, "item_ids": {"type": "array", "items": {"type": "string"}}},
            "required": ["restaurant_id", "item_ids"]}},
    }},
    {"toolSpec": {
        "name": "submit_plan",
        "description": "Submit the final plan once. lines = what each person gets (option_ids from get_item_options).",
        "inputSchema": {"json": {"type": "object", "properties": {
            "restaurant_id": {"type": "integer"},
            "lines": {"type": "array", "items": {"type": "object", "properties": {
                "participant_id": {"type": "string"}, "item_id": {"type": "string"},
                "option_ids": {"type": "array", "items": {"type": "string"}}}, "required": ["participant_id", "item_id"]}},
            "reasoning": {"type": "string"},
            "per_person": {"type": "array", "items": {"type": "object", "properties": {
                "participant_id": {"type": "string"}, "why": {"type": "string"}}, "required": ["participant_id", "why"]}},
        }, "required": ["restaurant_id", "lines", "reasoning", "per_person"]}},
    }},
]


class AgentError(Exception):
    pass


def is_expired_credentials(e: Exception) -> bool:
    code = getattr(e, "response", {}).get("Error", {}).get("Code", "") if hasattr(e, "response") else ""
    return code in EXPIRED_CODES or "expired" in str(e).lower() or type(e).__name__ == "NoCredentialsError"


# ── What the model is told ───────────────────────────────────────────────────
def build_task(room: Room, group: dict, resolution: str) -> str:
    sig = dispute.signals(room)
    ranked = {r.restaurant.id: r for r in scoring.rank(dispute.deck_restaurants(room), sig)}
    names = {p: room.participants[p].name for p in group["participant_ids"]}
    people = []
    for pid in group["participant_ids"]:
        h = room.history.get(pid)
        votes = {}
        for rid in group["shortlist"]:
            r = room.catalog.by_id(rid)
            s = sig.swipe_r.get(pid, {}).get(rid, 0)
            votes[r.name] = {1: "liked", -1: "skipped", 0: "not seen"}[s]
        people.append({"participant_id": pid, "name": names[pid], "history": h.summary() if h else None, "votes": votes})
    shortlist = []
    for rid in group["shortlist"]:
        r, rk = room.catalog.by_id(rid), ranked.get(rid)
        shortlist.append({
            "restaurant_id": rid, "name": r.name, "category": r.category, "rating": r.rating, "eta_minutes": r.eta_minutes,
            "group_score": round(rk.group_score, 3) if rk else None,
            "liked_by": [names.get(p, p) for p in (rk.liked_by if rk else []) if p in names],
            "vetoed_by": [names.get(p, p) for p in (rk.vetoed_by if rk else []) if p in names],
        })
    return json.dumps({
        "task": "Build one food order for these people.", "how_the_group_decided": resolution,
        "meal": room.meal, "people": people, "shortlist": shortlist,
        "note": "History marked source 'demo' is simulated for demo friends.",
    }, ensure_ascii=False)


# ── Tool execution (read-only) ───────────────────────────────────────────────
class Session:
    """Per-plan state: menus and options the model has looked at (the validator reuses them)."""

    def __init__(self, room: Room, gw, group: dict, trace: Trace):
        self.room, self.gw, self.group, self.trace = room, gw, group, trace
        self.menus: dict[int, Restaurant] = {}
        self.options: dict[tuple[int, str], list] = {}

    def check_shortlisted(self, rid) -> int:
        if rid not in self.group["shortlist"]:
            raise PlanFailed(f"restaurant {rid} is not on the shortlist {self.group['shortlist']}")
        return rid

    async def menu(self, rid: int) -> Restaurant:
        if rid not in self.menus:
            self.menus[rid] = await lookup(
                self.trace, self.gw.cached, "food_get_restaurant_menu", {"restaurant_id": rid}, lambda: self.gw.menu(rid),
                lambda r: f"{r.name}: {'open' if r.available else 'CLOSED'}, {len([d for d in r.dishes if d.active])} dishes.")
        return self.menus[rid]

    async def tool_menu(self, args: dict) -> dict:
        rid = self.check_shortlisted(int(args["restaurant_id"]))
        try:
            r = await self.menu(rid)
        except LookupFailed as e:
            return {"error": f"Could not load the menu: {e}. Try another shortlisted restaurant."}
        return {"restaurant_id": rid, "name": r.name, "open": r.available, "currency": r.currency,
                "dishes": [{"item_id": d.id, "name": d.name, "price": d.price, "requires_options": d.requires_options}
                           for d in r.dishes if d.active]}

    async def tool_options(self, args: dict) -> dict:
        rid = self.check_shortlisted(int(args["restaurant_id"]))
        ids = [str(i) for i in args.get("item_ids", [])]
        try:
            got = await lookup(self.trace, self.gw.cached, "food_get_items_options", {"restaurant_id": rid, "item_ids": ids},
                               lambda: self.gw.options(rid, ids), lambda r: f"Option groups for {len(r)} item(s).")
        except LookupFailed as e:
            return {"error": f"Could not load options: {e}."}
        for item_id, groups in got.items():
            self.options[(rid, item_id)] = groups
        return {"items": [{"item_id": i, "option_groups": [
            {"group_id": g.id, "name": g.name, "required": g.required, "min": g.min, "max": g.max,
             "options": [{"option_id": o.catalog_option_id, "name": o.name, "price": o.price} for o in g.options]} for g in groups]}
            for i, groups in got.items()]}

    async def validate(self, plan_in: dict) -> Plan:
        """Rebuild the plan from ids and re-check everything. Raises PlanFailed with a message the model can act on."""
        rid = self.check_shortlisted(int(plan_in["restaurant_id"]))
        rest = await self.menu(rid)
        if not rest.available:
            raise PlanFailed(f"{rest.name} is closed. Choose another shortlisted restaurant.")
        pids = self.group["participant_ids"]
        dishes = {d.id: d for d in rest.dishes if d.active}
        lines: list[PlanLine] = []
        for ln in plan_in.get("lines", []):
            pid, dish = ln.get("participant_id"), dishes.get(str(ln.get("item_id")))
            if pid not in pids:
                raise PlanFailed(f"unknown participant_id {pid}")
            if not dish:
                raise PlanFailed(f"item {ln.get('item_id')} is not an active dish of {rest.name}")
            groups = self.options.get((rid, dish.id), dish.option_groups)
            by_id = {o.catalog_option_id: o for g in groups for o in g.options}
            chosen: list[Option] = []
            for oid in ln.get("option_ids", []) or []:
                if oid not in by_id:
                    raise PlanFailed(f"option {oid} does not belong to {dish.name}")
                chosen.append(by_id[oid])
            validate_options(dish, groups, chosen)
            lines.append(PlanLine(pid, dish, chosen))
        missing = [self.room.participants[p].name for p in pids if p not in {l.participant_id for l in lines}]
        if missing:
            raise PlanFailed("these people have no dish: " + ", ".join(missing))
        for pid in pids:
            if sum(1 for l in lines if l.participant_id == pid) > 2:
                raise PlanFailed(f"{self.room.participants[pid].name} has more than 2 dishes")
        why = {p.get("participant_id"): str(p.get("why", ""))[:200] for p in plan_in.get("per_person", [])}
        first = {l.participant_id: l.dish for l in reversed(lines)}
        per_person = [{"participant_id": p, "name": self.room.participants[p].name,
                       "why": why.get(p) or why_for(self.room, p, rest, first[p])} for p in pids]
        reasoning = str(plan_in.get("reasoning", "")).strip()[:240] or group_reasoning(self.room, rest, self.group, "consensus")
        return Plan(rest, lines, reasoning, per_person, source="agent")


# ── The loop ─────────────────────────────────────────────────────────────────
async def plan_with_agent(room: Room, gw, group: dict, trace: Trace, resolution: str, converse=None) -> Plan:
    converse = converse or bedrock_client.converse
    s = Session(room, gw, group, trace)
    messages = [{"role": "user", "content": [{"text": build_task(room, group, resolution)}]}]
    tokens, started, repairs = 0, time.time(), 0
    trace.add("bedrock_agent", {"model": bedrock_client.MODEL_ID}, "Agent started: reading the votes, history and shortlist.")

    for i in range(MAX_ITERATIONS):
        resp = await asyncio.to_thread(
            converse, messages, system=[{"text": SYSTEM}], toolConfig={"tools": TOOLS},
            inferenceConfig={"maxTokens": 1500, "temperature": 0})
        u = resp.get("usage", {})
        tokens += u.get("inputTokens", 0) + u.get("outputTokens", 0)
        msg = resp["output"]["message"]
        messages.append(msg)
        calls = [c["toolUse"] for c in msg["content"] if "toolUse" in c]
        if not calls:
            messages.append({"role": "user", "content": [{"text": "Continue. Call a tool, or submit_plan when ready."}]})
            continue
        results = []
        for call in calls:
            name, args = call["name"], call.get("input", {})
            try:
                if name == "get_restaurant_menu":
                    out = await s.tool_menu(args)
                elif name == "get_item_options":
                    out = await s.tool_options(args)
                elif name == "submit_plan":
                    plan = await s.validate(args)
                    trace.add("submit_plan", {"restaurant_id": plan.restaurant.id},
                              f"Plan accepted for {plan.restaurant.name} after {i + 1} model call(s), {tokens} tokens, {time.time() - started:.1f}s.")
                    log.info("agent ok: room=%s calls=%d tokens=%d secs=%.1f", room.code, i + 1, tokens, time.time() - started)
                    return plan
                else:
                    out = {"error": f"unknown tool {name}"}
                status = "error" if "error" in out else "success"
            except (PlanFailed, ValueError, KeyError, TypeError) as e:
                out, status = {"error": f"Rejected: {e}"}, "error"
                if name == "submit_plan":
                    repairs += 1
                    trace.add("submit_plan", {}, f"Plan rejected: {e}", failed=True)
                    if repairs > 1:
                        raise AgentError(f"plan rejected twice: {e}") from e
            results.append({"toolResult": {"toolUseId": call["toolUseId"], "content": [{"text": json.dumps(out, ensure_ascii=False)}], "status": status}})
        messages.append({"role": "user", "content": results})
    raise AgentError(f"no plan after {MAX_ITERATIONS} model calls ({tokens} tokens)")
