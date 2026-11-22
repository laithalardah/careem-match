"""Bedrock agent: picks the restaurant the group goes to, from the shortlist, using tool use.

Converse API, model global.anthropic.claude-sonnet-5-5 (us-east-1), at most MAX_ITERATIONS model calls.
The model sees only READ-ONLY tools (look at a restaurant's menu/status) plus `submit_plan`. What it submits is
re-checked by code (validate): the restaurant must be on the shortlist, open, and have something to order.
On any problem planner.py takes over. There are no dishes or baskets: the group orders in Careem itself.
"""
from __future__ import annotations

import asyncio
import json
import logging
import time

import bedrock_client
import dispute
import scoring
from catalog import Restaurant
from planner import LookupFailed, Plan, PlanFailed, Trace, check_orderable, group_reasoning, lookup, menu_summary, why_for
from rooms import Room

log = logging.getLogger("agent")
MAX_ITERATIONS = 8
EXPIRED_CODES = {"ExpiredTokenException", "ExpiredToken", "UnrecognizedClientException", "InvalidSignatureException", "InvalidClientTokenId"}

SYSTEM = """You are the matching agent of Careem Match. A group of friends swiped on restaurants; you decide which ONE restaurant they go to. After you decide, the app sends everyone to that restaurant in Careem, where they start a normal group order and pick their own dishes.

Rules you must follow:
- Choose the restaurant ONLY from the shortlist. If the group already decided (a single restaurant on the shortlist), use it.
- Prefer a restaurant liked by most people with nobody vetoing it. Never pick a vetoed restaurant unless nothing else works.
- Call get_restaurant_menu to check the restaurant is open and has dishes. If it is closed or the call fails, move to the next shortlisted restaurant (re-plan).
- Use only ids you were given. Never invent restaurants.
- Finish by calling submit_plan exactly once. The reasoning must be ONE short sentence that is true given the data. Each person's `why` is one short sentence addressed to that person ("You liked ...", "You ordered here 4 days ago"), about why this restaurant suits them (their votes, their history); never start it with their name.
- You can only look things up. You never order, add to a cart, or pay.
- Tool errors are readable messages. Explain them to yourself and decide whether another restaurant is the better choice.
- Do not talk about dishes or prices in the reasoning: people choose their own in Careem."""

TOOLS = [
    {"toolSpec": {
        "name": "get_restaurant_menu",
        "description": "Read-only. Is the restaurant open, how is it rated, how long is delivery, and what are its top dishes?",
        "inputSchema": {"json": {"type": "object", "properties": {"restaurant_id": {"type": "integer"}}, "required": ["restaurant_id"]}},
    }},
    {"toolSpec": {
        "name": "submit_plan",
        "description": "Submit the final choice once.",
        "inputSchema": {"json": {"type": "object", "properties": {
            "restaurant_id": {"type": "integer"},
            "reasoning": {"type": "string"},
            "per_person": {"type": "array", "items": {"type": "object", "properties": {
                "participant_id": {"type": "string"}, "why": {"type": "string"}}, "required": ["participant_id", "why"]}},
        }, "required": ["restaurant_id", "reasoning", "per_person"]}},
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
        "task": "Choose the one restaurant this group goes to.", "how_the_group_decided": resolution,
        "meal": room.meal, "people": people, "shortlist": shortlist,
        "note": "History marked source 'demo' is simulated for demo friends.",
    }, ensure_ascii=False)


# ── Tool execution (read-only) ───────────────────────────────────────────────
class Session:
    """Per-plan state: menus the model has looked at (the validator reuses them)."""

    def __init__(self, room: Room, gw, group: dict, trace: Trace):
        self.room, self.gw, self.group, self.trace = room, gw, group, trace
        self.menus: dict[int, Restaurant] = {}

    def check_shortlisted(self, rid) -> int:
        if rid not in self.group["shortlist"]:
            raise PlanFailed(f"restaurant {rid} is not on the shortlist {self.group['shortlist']}")
        return rid

    async def menu(self, rid: int) -> Restaurant:
        if rid not in self.menus:
            self.menus[rid] = await lookup(self.trace, self.gw.cached, "food_get_restaurant_menu", {"restaurant_id": rid},
                                           lambda: self.gw.menu(rid), menu_summary)
        return self.menus[rid]

    async def tool_menu(self, args: dict) -> dict:
        rid = self.check_shortlisted(int(args["restaurant_id"]))
        try:
            r = await self.menu(rid)
        except LookupFailed as e:
            return {"error": f"Could not load the restaurant: {e}. Try another shortlisted restaurant."}
        return {"restaurant_id": rid, "name": r.name, "open": r.available, "rating": r.rating, "eta_minutes": r.eta_minutes,
                "top_dishes": r.top_dishes, "currency": r.currency}

    async def validate(self, plan_in: dict) -> Plan:
        """Re-check the submitted choice. Raises PlanFailed with a message the model can act on."""
        rid = self.check_shortlisted(int(plan_in["restaurant_id"]))
        rest = await self.menu(rid)
        try:
            check_orderable(rest)
        except PlanFailed as e:
            raise PlanFailed(f"{e}. Choose another shortlisted restaurant.") from e
        pids = self.group["participant_ids"]
        why = {p.get("participant_id"): str(p.get("why", ""))[:200] for p in plan_in.get("per_person", [])}
        per_person = [{"participant_id": p, "name": self.room.participants[p].name, "why": why.get(p) or why_for(self.room, p, rest)}
                      for p in pids]
        reasoning = str(plan_in.get("reasoning", "")).strip()[:240] or group_reasoning(self.room, rest, self.group, "consensus")
        return Plan(rest, reasoning, per_person, source="agent")


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
            inferenceConfig={"maxTokens": 1000})  # no `temperature`: deprecated for this model (Bedrock rejects it)
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
                elif name == "submit_plan":
                    plan = await s.validate(args)
                    trace.add("submit_plan", {"restaurant_id": plan.restaurant.id},
                              f"Choice accepted: {plan.restaurant.name} after {i + 1} model call(s), {tokens} tokens, {time.time() - started:.1f}s.")
                    log.info("agent ok: room=%s calls=%d tokens=%d secs=%.1f", room.code, i + 1, tokens, time.time() - started)
                    return plan
                else:
                    out = {"error": f"unknown tool {name}"}
                status = "error" if "error" in out else "success"
            except (PlanFailed, ValueError, KeyError, TypeError) as e:
                out, status = {"error": f"Rejected: {e}"}, "error"
                if name == "submit_plan":
                    repairs += 1
                    trace.add("submit_plan", {}, f"Choice rejected: {e}", failed=True)
                    if repairs > 1:
                        raise AgentError(f"choice rejected twice: {e}") from e
            results.append({"toolResult": {"toolUseId": call["toolUseId"], "content": [{"text": json.dumps(out, ensure_ascii=False)}], "status": status}})
        messages.append({"role": "user", "content": results})
    raise AgentError(f"no choice after {MAX_ITERATIONS} model calls ({tokens} tokens)")
