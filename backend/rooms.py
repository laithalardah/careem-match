"""Room state machine (in-memory). Pure functions on Room; the API layer lives in main.py.

Stages: lobby -> settings -> swiping -> dispute (only if no consensus) -> matching -> result -> ordered
"""
from __future__ import annotations

import secrets
import time
from dataclasses import dataclass, field
from typing import Any, Callable

import config
from catalog import MEAL_CATEGORIES, Catalog

CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
MEALS = tuple(MEAL_CATEGORIES)
MODES = ("food", "dineout")


class ApiError(Exception):
    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status, self.message = status, message


@dataclass
class Participant:
    id: str
    name: str
    is_host: bool = False
    is_bot: bool = False
    persona: dict | None = None  # demo friends only
    joined_at: float = field(default_factory=time.time)


@dataclass
class Room:
    code: str
    mode: str
    host_id: str
    stage: str = "lobby"
    version: int = 0
    level: str | None = None
    meal: str | None = None
    participants: dict[str, Participant] = field(default_factory=dict)
    cards: dict[str, list[dict]] = field(default_factory=dict)
    swipes: dict[str, dict[str, dict[str, bool]]] = field(default_factory=dict)  # pid -> level -> card_id -> liked
    dispute: dict | None = None
    result: dict | None = None
    order: dict | None = None
    forced: dict[str, Any] | None = None  # e.g. {"restaurant_id": 30101} after a wheel spin
    catalog: Catalog | None = None
    created_at: float = field(default_factory=time.time)
    tasks: list = field(default_factory=list)

    def touch(self) -> None:
        self.version += 1


ROOMS: dict[str, Room] = {}
# Engine registers this; called once when everybody has finished the restaurant level.
HOOKS: dict[str, Callable[[Room], None]] = {}


# ── Lookups and guards ───────────────────────────────────────────────────────
def get_room(code: str) -> Room:
    room = ROOMS.get(code.upper())
    if not room:
        raise ApiError(404, "Room not found. Check the code and try again.")
    return room


def require_participant(room: Room, pid: str | None) -> Participant:
    p = room.participants.get(pid or "")
    if not p:
        raise ApiError(403, "You are not in this room.")
    return p


def require_host(room: Room, pid: str | None) -> Participant:
    p = require_participant(room, pid)
    if not p.is_host:
        raise ApiError(403, "Only the host can do that.")
    return p


def require_stage(room: Room, *stages: str) -> None:
    if room.stage not in stages:
        raise ApiError(409, f"Not possible right now (room is in '{room.stage}').")


# ── Creating and joining ─────────────────────────────────────────────────────
def _new_id() -> str:
    return "p_" + secrets.token_urlsafe(6)


def _clean_name(name: str) -> str:
    name = " ".join((name or "").split())
    if not name:
        raise ApiError(422, "Please enter a name.")
    if len(name) > 24:
        raise ApiError(422, "Names can be up to 24 characters.")
    return name


def create_room(mode: str, host_name: str) -> tuple[Room, str]:
    if mode not in MODES:
        raise ApiError(422, "Mode must be 'food' or 'dineout'.")
    name = _clean_name(host_name)
    code = "".join(secrets.choice(CODE_ALPHABET) for _ in range(6))
    while code in ROOMS:
        code = "".join(secrets.choice(CODE_ALPHABET) for _ in range(6))
    pid = _new_id()
    room = Room(code=code, mode=mode, host_id=pid)
    room.participants[pid] = Participant(id=pid, name=name, is_host=True)
    room.touch()
    ROOMS[code] = room
    return room, pid


def join(room: Room, name: str, *, is_bot: bool = False, persona: dict | None = None) -> Participant:
    require_stage(room, "lobby")
    name = _clean_name(name)
    taken = {p.name.lower() for p in room.participants.values()}
    base, n = name, 2
    while name.lower() in taken:  # keep names distinguishable
        name = f"{base} {n}"
        n += 1
    p = Participant(id=_new_id(), name=name, is_bot=is_bot, persona=persona)
    room.participants[p.id] = p
    room.touch()
    return p


# ── Host steps ───────────────────────────────────────────────────────────────
def go_next(room: Room, pid: str) -> None:
    require_host(room, pid)
    require_stage(room, "lobby")
    if len(room.participants) < 2:
        raise ApiError(409, "Wait for at least one more person to join.")
    room.stage = "settings"
    room.touch()


def set_meal(room: Room, pid: str, meal: str) -> None:
    require_host(room, pid)
    require_stage(room, "settings")
    if meal not in MEALS:
        raise ApiError(422, f"Meal must be one of: {', '.join(MEALS)}.")
    room.meal = meal
    room.touch()


def start(room: Room, pid: str, catalog: Catalog) -> None:
    require_host(room, pid)
    require_stage(room, "settings")
    if not room.meal:
        raise ApiError(409, "Pick a meal first.")
    cards = catalog.category_cards(room.meal)
    if not cards:
        raise ApiError(409, f"No open restaurants for {room.meal} nearby. Try another meal.")
    room.catalog = catalog
    room.cards = {"category": cards}
    room.swipes = {p: {} for p in room.participants}
    room.level, room.stage = "category", "swiping"
    room.touch()


# ── Swiping ──────────────────────────────────────────────────────────────────
def swipes_at(room: Room, pid: str, level: str) -> dict[str, bool]:
    return room.swipes.get(pid, {}).get(level, {})


def progress(room: Room, p: Participant) -> dict:
    if room.stage != "swiping" or not room.level:
        return {"level": room.level, "swiped": 0, "total": 0, "done": room.stage not in ("lobby", "settings", "swiping")}
    total = len(room.cards.get(room.level, []))
    swiped = len(swipes_at(room, p.id, room.level))
    return {"level": room.level, "swiped": swiped, "total": total, "done": total > 0 and swiped >= total}


def cards_for(room: Room, pid: str) -> dict:
    require_participant(room, pid)
    require_stage(room, "swiping")
    return {"level": room.level, "cards": room.cards.get(room.level or "", [])}


def swipe(room: Room, pid: str, level: str, card_id: str, liked: bool) -> dict:
    require_participant(room, pid)
    require_stage(room, "swiping")
    if level != room.level:
        raise ApiError(409, f"The room is on the '{room.level}' level.")
    if card_id not in {c["id"] for c in room.cards.get(level, [])}:
        raise ApiError(422, "Unknown card.")
    room.swipes.setdefault(pid, {}).setdefault(level, {})[card_id] = bool(liked)
    room.touch()
    done = len(swipes_at(room, pid, level)) >= len(room.cards[level])
    _maybe_advance(room)
    return {"ok": True, "level_done": done}


def all_done(room: Room, level: str) -> bool:
    total = len(room.cards.get(level, []))
    return total > 0 and all(len(swipes_at(room, p, level)) >= total for p in room.participants)


def liked_card_ids(room: Room, level: str) -> set[str]:
    return {cid for p in room.participants for cid, liked in swipes_at(room, p, level).items() if liked}


def _maybe_advance(room: Room) -> None:
    if room.stage != "swiping" or not room.level or not all_done(room, room.level):
        return
    if room.level == "category":
        liked = liked_card_ids(room, "category")
        titles = {c["title"] for c in room.cards["category"] if c["id"] in liked}
        deck = room.catalog.restaurant_cards(titles, room.meal) if (room.catalog and titles) else []
        if not deck:
            finish_no_match(room, "Nobody liked a category with an open restaurant.")
            return
        room.cards["restaurant"] = deck
        room.level = "restaurant"
        room.touch()
    else:
        hook = HOOKS.get("restaurants_done")
        if hook:
            hook(room)


def finish_no_match(room: Room, reason: str) -> None:
    room.stage = "result"
    room.result = empty_result("no_match", reason)
    room.touch()


def empty_result(status: str, reasoning: str = "", resolution: str = "consensus") -> dict:
    return {
        "status": status, "resolution": {"type": resolution}, "groups": [],
        "restaurant": None, "basket": [], "total_price": 0, "currency": "", "reasoning": reasoning,
        "per_person": [], "scores": [], "agent_trace": [],
    }


# ── Public view ──────────────────────────────────────────────────────────────
def to_dict(room: Room) -> dict:
    return {
        "room_code": room.code,
        "mode": room.mode,
        "stage": room.stage,
        "version": room.version,
        "host_id": room.host_id,
        "join_url": f"{config.public_app_url()}/#/join/{room.code}",
        "level": room.level if room.stage == "swiping" else None,
        "settings": {"meal": room.meal},
        "participants": [
            {"id": p.id, "name": p.name, "is_host": p.is_host, "is_bot": p.is_bot, "progress": progress(room, p)}
            for p in sorted(room.participants.values(), key=lambda p: p.joined_at)
        ],
        "dispute": room.dispute if room.stage == "dispute" else None,
    }
