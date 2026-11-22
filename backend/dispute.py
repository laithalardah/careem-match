"""Consensus check and dispute resolution (wheel or split). See docs/v2-plan.md section 3b.

Consensus = a restaurant liked by >= CONSENSUS_THRESHOLD of people with nobody vetoing it.
Otherwise the group is in a dispute: everyone votes `wheel` or `split`.
  wheel  one restaurant, drawn on the SERVER (secrets), slices sized by supporters
  split  one group (and one order) per restaurant camp; people can move until the host confirms
Wheel angle convention: slices start at the top (0 deg) and run clockwise in `segments` order.
`final_angle_deg` is the clockwise rotation (0..360) of the wheel at rest that puts the winner's slice
under the fixed top pointer.
"""
from __future__ import annotations

import asyncio
import secrets
import time
import uuid
from dataclasses import dataclass, field

import config
import rooms
import scoring
from rooms import ApiError, Room


# ── Signals ──────────────────────────────────────────────────────────────────
def deck_restaurants(room: Room) -> list:
    ids = [int(c["id"]) for c in room.cards.get("restaurant", [])]
    return [r for r in (room.catalog.by_id(i) for i in ids) if r]


def signals(room: Room) -> scoring.Signals:
    pids = list(room.participants)
    cat_by_card = {c["id"]: c["title"] for c in room.cards.get("category", [])}
    sig = scoring.Signals(participant_ids=pids)
    for pid in pids:
        sig.swipe_c[pid] = {cat_by_card[cid]: (1 if v else -1) for cid, v in rooms.swipes_at(room, pid, "category").items() if cid in cat_by_card}
        sig.swipe_r[pid] = {int(cid): (1 if v else -1) for cid, v in rooms.swipes_at(room, pid, "restaurant").items()}
        h = room.history.get(pid)
        sig.hist_r[pid] = dict(h.restaurant) if h else {}
        sig.hist_c[pid] = dict(h.category) if h else {}
    return sig


# ── Evaluation ───────────────────────────────────────────────────────────────
@dataclass
class Outcome:
    kind: str  # "consensus" | "dispute" | "no_match"
    ranked: list = field(default_factory=list)
    shortlist: list = field(default_factory=list)  # Ranked, best first (consensus)
    compromise: bool = False
    contenders: list = field(default_factory=list)  # [{"ranked": Ranked, "supporters": [pid]}] (dispute)


def evaluate(room: Room) -> Outcome:
    sig = signals(room)
    ranked = scoring.rank(deck_restaurants(room), sig)
    n = len(sig.participant_ids)
    if not any(r.likes for r in ranked):
        return Outcome("no_match", ranked)

    thr = config.consensus_threshold()
    agreed = [r for r in ranked if not r.vetoed_by and r.likes / n >= thr]
    liked = [r for r in ranked if r.likes > 0]  # never shortlist a place nobody liked
    if agreed:
        rest, _ = scoring.shortlist([r for r in liked if r not in agreed])
        return Outcome("consensus", ranked, (agreed + [r for r in rest if r not in agreed])[:3])

    contenders = _contenders(ranked, sig)
    if len(contenders) < 2:  # everyone's favourite is the same place, it just fell short of the bar
        short, _ = scoring.shortlist(liked)
        first = contenders[0]["ranked"] if contenders else short[0]
        return Outcome("consensus", ranked, [first] + [r for r in short if r is not first][:2], compromise=True)
    return Outcome("dispute", ranked, contenders=contenders)


def _contenders(ranked: list, sig: scoring.Signals, max_n: int = 3) -> list[dict]:
    by_rid = {r.restaurant.id: r for r in ranked}
    top: dict[str, int | None] = {}
    for pid in sig.participant_ids:
        liked = [r for r in ranked if pid in r.liked_by]
        top[pid] = max(liked, key=lambda r: r.per_person[pid]).restaurant.id if liked else None
    support: dict[int, list[str]] = {}
    for pid, rid in top.items():
        if rid is not None:
            support.setdefault(rid, []).append(pid)
    kept = sorted(support, key=lambda rid: (-len(support[rid]), -by_rid[rid].group_score))[:max_n]
    if not kept:
        return []
    for pid, rid in top.items():  # neutral people and people whose favourite was dropped
        if rid not in kept:
            best = max(kept, key=lambda k: (by_rid[k].per_person[pid], by_rid[k].group_score))
            support.setdefault(best, []).append(pid)
    return [{"ranked": by_rid[rid], "supporters": support[rid]} for rid in kept]


# ── Starting a dispute ───────────────────────────────────────────────────────
def start_dispute(room: Room, outcome: Outcome, reason: str) -> None:
    room.stage = "dispute"
    room.dispute = {
        "reason": reason,
        "contenders": [
            {"restaurant_id": c["ranked"].restaurant.id, "name": c["ranked"].restaurant.name,
             "image_url": c["ranked"].restaurant.image_url, "cuisine": c["ranked"].restaurant.category,
             "supporter_ids": list(c["supporters"])}
            for c in outcome.contenders
        ],
        "method_votes": {}, "method": None, "wheel": None, "split": None,
    }
    room.touch()


def start_early(room: Room, pid: str) -> None:
    """Host asks for help deciding before everyone is done."""
    rooms.require_host(room, pid)
    rooms.require_stage(room, "swiping")
    if room.level != "restaurant":
        raise ApiError(409, "Pick a category first, then restaurants.")
    need = min(config.dispute_min_swipes(), len(room.cards["restaurant"]))
    if len(rooms.swipes_at(room, pid, "restaurant")) < need:
        raise ApiError(409, f"Swipe at least {need} restaurants first.")
    out = evaluate(room)
    if out.kind != "dispute":
        msg = "Nobody has liked a restaurant yet." if out.kind == "no_match" else "No disagreement so far. Keep swiping."
        raise ApiError(409, msg)
    start_dispute(room, out, "host_requested")


# ── Voting ───────────────────────────────────────────────────────────────────
def cast_vote(room: Room, pid: str, method: str) -> None:
    rooms.require_participant(room, pid)
    rooms.require_stage(room, "dispute")
    d = room.dispute
    if d["method"]:
        raise ApiError(409, "The method is already decided.")
    if method not in ("wheel", "split"):
        raise ApiError(422, "Vote 'wheel' or 'split'.")
    d["method_votes"][pid] = method
    room.touch()
    _settle_method(room)


def _settle_method(room: Room) -> None:
    d, n = room.dispute, len(room.participants)
    votes = list(d["method_votes"].values())
    wheel, split = votes.count("wheel"), votes.count("split")
    if wheel * 2 > n:
        method = "wheel"
    elif split * 2 > n:
        method = "split"
    elif len(votes) == n:  # everyone voted and it is a tie: the host's vote decides
        method = d["method_votes"][room.host_id]
    else:
        return
    d["method"] = method
    if method == "wheel":
        d["wheel"] = {
            "segments": [{"restaurant_id": c["restaurant_id"], "name": c["name"], "weight": float(len(c["supporter_ids"]))}
                         for c in d["contenders"]],
            "spin_id": None, "spin_started_at_ms": None, "duration_ms": config.wheel_duration_ms(),
            "final_angle_deg": None, "winner_restaurant_id": None,
        }
    else:
        d["split"] = {
            "groups": [{"restaurant_id": c["restaurant_id"], "name": c["name"], "image_url": c["image_url"],
                        "participant_ids": list(c["supporter_ids"])} for c in d["contenders"]],
            "confirmed": False,
        }
    room.touch()


# ── Wheel ────────────────────────────────────────────────────────────────────
def draw_winner(weights: list[float]) -> int:
    """Index of the winning slice, probability proportional to weight. Uses `secrets`, never the client."""
    pick = secrets.SystemRandom().uniform(0, sum(weights))
    acc = 0.0
    for i, w in enumerate(weights):
        acc += w
        if pick < acc:
            return i
    return len(weights) - 1


def landing_angle(weights: list[float], index: int) -> float:
    """Clockwise wheel rotation (0..360) that puts a random point inside slice `index` under the top pointer."""
    total = sum(weights)
    start = sum(weights[:index]) / total * 360
    span = weights[index] / total * 360
    target = start + span * (0.1 + 0.8 * secrets.SystemRandom().random())  # stay clear of slice edges
    return (360 - target) % 360


def spin(room: Room, pid: str) -> None:
    rooms.require_host(room, pid)
    rooms.require_stage(room, "dispute")
    d = room.dispute
    if d["method"] != "wheel":
        raise ApiError(409, "The group did not choose the wheel.")
    w = d["wheel"]
    if w["spin_id"]:
        raise ApiError(409, "The wheel was already spun.")
    weights = [s["weight"] for s in w["segments"]]
    i = draw_winner(weights)
    w.update({
        "spin_id": uuid.uuid4().hex, "spin_started_at_ms": int(time.time() * 1000),
        "final_angle_deg": round(landing_angle(weights, i), 2), "winner_restaurant_id": w["segments"][i]["restaurant_id"],
    })
    room.touch()
    delay = (w["duration_ms"] + config.wheel_reveal_pause_ms()) / 1000
    room.tasks.append(asyncio.get_running_loop().create_task(_after_spin(room, w["winner_restaurant_id"], delay)))


async def _after_spin(room: Room, winner: int, delay: float) -> None:
    await asyncio.sleep(delay)
    if room.stage == "dispute":
        import engine

        engine.begin_matching(room, [{"shortlist": [winner], "participant_ids": list(room.participants)}], "wheel")


# ── Split ────────────────────────────────────────────────────────────────────
def move(room: Room, pid: str, restaurant_id: int) -> None:
    rooms.require_participant(room, pid)
    rooms.require_stage(room, "dispute")
    s = room.dispute.get("split")
    if room.dispute["method"] != "split" or not s:
        raise ApiError(409, "The group did not choose to split.")
    if s["confirmed"]:
        raise ApiError(409, "Groups are already confirmed.")
    target = next((g for g in s["groups"] if g["restaurant_id"] == restaurant_id), None)
    if not target:
        raise ApiError(422, "That group does not exist.")
    for g in s["groups"]:
        g["participant_ids"] = [x for x in g["participant_ids"] if x != pid]
    target["participant_ids"].append(pid)
    s["groups"] = [g for g in s["groups"] if g["participant_ids"]]  # empty groups vanish
    room.touch()
    if len(s["groups"]) == 1:  # everyone ended up together: no need to split
        import engine

        engine.begin_matching(room, [{"shortlist": [s["groups"][0]["restaurant_id"]], "participant_ids": list(room.participants)}], "consensus")


def confirm(room: Room, pid: str) -> None:
    rooms.require_host(room, pid)
    rooms.require_stage(room, "dispute")
    s = room.dispute.get("split")
    if room.dispute["method"] != "split" or not s:
        raise ApiError(409, "The group did not choose to split.")
    s["confirmed"] = True
    room.touch()
    import engine

    engine.begin_matching(
        room, [{"shortlist": [g["restaurant_id"]], "participant_ids": list(g["participant_ids"])} for g in s["groups"]], "split")


# ── Demo friends ─────────────────────────────────────────────────────────────
def bot_action(room: Room, bot, rng) -> bool:
    if bot.id not in room.dispute["method_votes"] and not room.dispute["method"]:
        cast_vote(room, bot.id, rng.choice(["wheel", "split"]))
        return True
    return False
