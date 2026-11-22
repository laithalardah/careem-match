"""Demo friends: bots with a taste persona and seeded history, for demos and solo testing.

They join the room like people (is_bot=True), swipe with a delay, vote on the dispute method and
accept whatever group they were put in. Needs DEMO=1.
"""
from __future__ import annotations

import asyncio
import logging
import random
import time

import config
import rooms
from catalog import Catalog
from rooms import Participant, Room

log = logging.getLogger("demo")
NAMES = ["Lina", "Omar", "Sara", "Khaled", "Dana", "Yazan", "Reem", "Tariq"]


def _categories(catalog: Catalog) -> list[str]:
    """Categories that have an open restaurant, best-rated first (lunch menu is the widest)."""
    cats: dict[str, float] = {}
    for r in catalog.candidates("lunch") or catalog.candidates(None):
        cats[r.category] = max(cats.get(r.category, 0), r.rating or 0)
    return [c for c, _ in sorted(cats.items(), key=lambda kv: -kv[1])]


def make_personas(count: int, scenario: str, catalog: Catalog, rng: random.Random, taken: set[str]) -> list[dict]:
    cats = _categories(catalog)
    if not cats:
        raise rooms.ApiError(409, "No restaurants available for demo friends.")
    a, b = cats[0], cats[1 if len(cats) > 1 else 0]
    names = [n for n in NAMES if n.lower() not in taken][:count]
    personas = []
    for i, name in enumerate(names):
        if scenario == "consensus":  # everyone loves the same thing
            loves, dislikes = [a], []
        elif scenario == "dispute":  # two camps that dislike each other's favourite
            loves, dislikes = ([a], [b]) if i % 2 == 0 else ([b], [a])
        else:  # random tastes
            pool = cats[:]
            rng.shuffle(pool)
            loves = pool[: rng.choice([1, 1, 2])]
            rest = [c for c in pool if c not in loves]
            dislikes = rest[:1] if rest and rng.random() < 0.5 else []
        personas.append({"name": name, "loves": loves, "dislikes": dislikes})
    return personas


def add_friends(room: Room, count: int, scenario: str, catalog: Catalog) -> list[Participant]:
    rooms.require_stage(room, "lobby")
    if not 1 <= count <= 4:
        raise rooms.ApiError(422, "Add between 1 and 4 demo friends.")
    if len(room.participants) + count > 8:
        raise rooms.ApiError(409, "A room can have up to 8 people.")
    rng = random.Random(f"{room.code}:{scenario}")
    taken = {p.name.lower() for p in room.participants.values()}
    added = []
    for persona in make_personas(count, scenario, catalog, rng, taken):
        added.append(rooms.join(room, persona["name"], is_bot=True, persona=persona))
    return added


# ── Behaviour ────────────────────────────────────────────────────────────────
def _likes(card: dict, persona: dict, catalog: Catalog | None, rng: random.Random) -> bool:
    cat = card["title"] if card["level"] == "category" else card.get("cuisine", "")
    if cat in persona.get("dislikes", []):
        return False
    if cat in persona.get("loves", []):
        return rng.random() > 0.05  # almost always
    return rng.random() < 0.25


def _next_card(room: Room, pid: str) -> dict | None:
    done = rooms.swipes_at(room, pid, room.level or "")
    return next((c for c in room.cards.get(room.level or "", []) if c["id"] not in done), None)


def bot_step(room: Room, bot: Participant, rng: random.Random) -> bool:
    """Do at most one action. Returns True if something happened."""
    if room.stage == "swiping":
        card = _next_card(room, bot.id)
        if not card:
            return False
        rooms.swipe(room, bot.id, room.level, card["id"], _likes(card, bot.persona or {}, room.catalog, rng))
        return True
    if room.stage == "dispute":
        import dispute  # local import: dispute needs rooms and scoring

        return dispute.bot_action(room, bot, rng)
    return False


async def bot_loop(room: Room) -> None:
    """One background task per room; ends when the room leaves swiping/dispute."""
    rng = random.Random(room.code)
    next_at: dict[str, float] = {}
    try:
        while room.stage in ("swiping", "dispute"):
            now = time.monotonic()
            lo, hi = config.bot_delay_range()
            for bot in [p for p in room.participants.values() if p.is_bot]:
                if now >= next_at.get(bot.id, 0) and bot_step(room, bot, rng):
                    next_at[bot.id] = now + rng.uniform(lo, hi)
            await asyncio.sleep(0.05 if hi <= 0.2 else 0.25)
    except Exception:  # noqa: BLE001
        log.exception("bot loop crashed for room %s", room.code)


def ensure_bots_running(room: Room) -> None:
    if any(p.is_bot for p in room.participants.values()) and not any(not t.done() for t in room.tasks):
        room.tasks.append(asyncio.get_running_loop().create_task(bot_loop(room)))
