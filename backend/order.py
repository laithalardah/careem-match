"""Hand-off to Careem's own group order. This backend never orders, never touches a cart, never pays.

When the group has a restaurant, the host taps the button and the room moves to `ordered`: every phone then shows
"Go to <restaurant>" with the restaurant's Careem link. There the host starts Careem's normal group order, shares it,
and each person picks their own dishes inside Careem. (The Careem MCP has no group-order or multi-user cart tool, so
the app opens the restaurant for them instead.)

Nothing here calls the MCP at all.
"""
from __future__ import annotations

import rooms
from rooms import ApiError, Room


def _members(room: Room, pids: list[str]) -> str:
    names = [room.participants[p].name for p in pids if p in room.participants]
    return names[0] if len(names) == 1 else ", ".join(names[:-1]) + " and " + names[-1]


async def create_orders(room: Room, pid: str) -> dict:
    rooms.require_host(room, pid)
    if room.stage == "ordered" and room.order:
        return room.order  # idempotent: a second tap changes nothing
    rooms.require_stage(room, "result")
    if not room.result or room.result.get("status") != "ready" or not room.result.get("groups"):
        raise ApiError(409, "There is no restaurant to go to yet.")

    groups = []
    for g in room.result["groups"]:
        r = g["restaurant"]
        groups.append({
            "group_id": g["group_id"], "status": "go", "restaurant_name": r["name"], "restaurant_link": r["link"],
            "price_breakdown": None,
            "message": (f"Open {r['name']} in Careem and start a group order for {_members(room, g['participant_ids'])}. "
                        "Everyone picks their own dishes there."),
        })
    one = len(groups) == 1
    room.order = {
        "status": "go", "groups": groups,
        "message": f"Head to {groups[0]['restaurant_name']} in Careem and start a group order." if one
        else "Each group heads to its own restaurant in Careem to start a group order.",
    }
    room.stage = "ordered"
    room.touch()
    return room.order
