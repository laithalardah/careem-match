"""PLACEHOLDER (replaced in step 6): marks each group's first shortlisted restaurant as the result, no basket."""
from __future__ import annotations

import rooms
from rooms import Room


async def run_groups(room: Room, groups: list[dict], resolution: str) -> None:
    out = []
    for i, g in enumerate(groups):
        r = room.catalog.by_id(g["shortlist"][0])
        out.append({
            "group_id": f"g{i + 1}",
            "restaurant": {"id": r.id, "name": r.name, "image_url": r.image_url, "cuisine": r.category, "rating": r.rating, "link": r.link},
            "participant_ids": g["participant_ids"], "basket": [], "total_price": 0, "currency": r.currency,
            "reasoning": "placeholder", "per_person": [],
        })
    res = {**rooms.empty_result("ready", resolution=resolution), "groups": out, "scores": room.result["scores"]}
    first = out[0] if len(out) == 1 else {}
    res.update({k: first.get(k, res[k]) for k in ("restaurant", "basket", "total_price", "currency", "reasoning", "per_person")})
    room.result = res
    room.stage = "result"
    room.touch()
