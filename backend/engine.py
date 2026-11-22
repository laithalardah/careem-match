"""Matching engine entry point. Called when everybody finished the restaurant level.

(Step 1 stub: moves the room to 'matching'. Scoring, disputes and the agent are added in later steps.)
"""
from __future__ import annotations

import rooms
from rooms import Room


def on_restaurants_done(room: Room) -> None:
    room.stage = "matching"
    room.result = rooms.empty_result("running")
    room.touch()


rooms.HOOKS["restaurants_done"] = on_restaurants_done
