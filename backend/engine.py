"""Matching engine: decides what happens when everybody finished the restaurant level.

consensus -> matching (one group, shortlist of up to 3)       dispute -> stage 'dispute'
no_match  -> result 'no_match'

begin_matching() is also called by the dispute engine once the wheel has landed or the split is confirmed.
"""
from __future__ import annotations

import asyncio
import logging

import dispute
import rooms
import scoring
from rooms import Room

log = logging.getLogger("engine")


def on_restaurants_done(room: Room) -> None:
    out = dispute.evaluate(room)
    if out.kind == "no_match":
        rooms.finish_no_match(room, "Nobody liked a restaurant.")
    elif out.kind == "dispute":
        dispute.start_dispute(room, out, "no_consensus")
    else:
        groups = [{
            "shortlist": [r.restaurant.id for r in out.shortlist],
            "participant_ids": list(room.participants),
            "compromise": out.compromise,
        }]
        begin_matching(room, groups, "consensus")


def begin_matching(room: Room, groups: list[dict], resolution: str) -> None:
    """groups: [{shortlist: [restaurant ids, best first], participant_ids: [...]}]"""
    if room.stage == "matching":
        return  # already running (e.g. a duplicate trigger)
    room.stage = "matching"
    result = rooms.empty_result("running", resolution=resolution)
    result["scores"] = scoring.public_scores(dispute.evaluate(room).ranked) if room.cards.get("restaurant") else []
    room.result = result
    room.touch()
    room.tasks.append(asyncio.get_running_loop().create_task(_run(room, groups, resolution)))


async def _run(room: Room, groups: list[dict], resolution: str) -> None:
    try:
        import planner  # noqa: F401  (added in step 6)  # noqa

        await planner.run_groups(room, groups, resolution)
    except Exception as e:  # noqa: BLE001
        log.exception("matching failed for room %s", room.code)
        room.result = {**rooms.empty_result("failed", f"The match could not be completed: {e}", resolution), "scores": room.result["scores"]}
        room.stage = "result"
        room.touch()


rooms.HOOKS["restaurants_done"] = on_restaurants_done
