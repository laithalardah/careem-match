"""Careem Match backend: FastAPI app implementing API v2.1 (see docs/v2-plan.md).

Run:  DEMO=1 uvicorn main:app --host 0.0.0.0 --port 8000
All state-changing handlers are `async def`, so room mutations run on the event loop and never race.
"""
from __future__ import annotations

import os
from pathlib import Path
from typing import Literal

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

import config
import demo
import dispute
import engine  # noqa: F401  (registers the matching hook)
import history
import order
import rooms
from catalog import get_catalog
from rooms import ApiError

app = FastAPI(title="Careem Match", version="2.1")
# `Date` is exposed so the app can estimate each phone's clock offset and start the wheel in sync.
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"], expose_headers=["Date"])


@app.exception_handler(ApiError)
async def api_error_handler(_: Request, e: ApiError):
    return JSONResponse(status_code=e.status, content={"detail": e.message})


# ── Request bodies ───────────────────────────────────────────────────────────
class CreateRoom(BaseModel):
    mode: Literal["food", "dineout"]
    host_name: str


class Join(BaseModel):
    name: str


class Actor(BaseModel):
    participant_id: str


class Settings(Actor):
    meal: str


class Swipe(Actor):
    level: Literal["category", "restaurant"]
    card_id: str
    liked: bool


class DemoFriends(Actor):
    count: int = 2
    scenario: Literal["consensus", "dispute", "random"] = "random"


class Vote(Actor):
    method: Literal["wheel", "split"]


class Move(Actor):
    restaurant_id: int


class Kick(Actor):
    target_id: str


# ── Basics ───────────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    return {"status": "ok", "demo": config.demo_enabled()}


@app.post("/rooms")
async def create_room(body: CreateRoom):
    room, pid = rooms.create_room(body.mode, body.host_name)
    return {"room_code": room.code, "participant_id": pid, "join_url": rooms.to_dict(room)["join_url"]}


@app.post("/rooms/{code}/join")
async def join_room(code: str, body: Join):
    room = rooms.get_room(code)
    p = rooms.join(room, body.name)
    return {"participant_id": p.id}


@app.get("/rooms/{code}")
async def get_room(code: str, participant_id: str | None = None):
    room = rooms.get_room(code)
    if participant_id is not None:
        rooms.require_participant(room, participant_id)
    return rooms.to_dict(room)


# ── Host steps ───────────────────────────────────────────────────────────────
@app.post("/rooms/{code}/next")
async def next_stage(code: str, body: Actor):
    rooms.go_next(rooms.get_room(code), body.participant_id)
    return {"ok": True}


@app.put("/rooms/{code}/settings")
async def put_settings(code: str, body: Settings):
    rooms.set_meal(rooms.get_room(code), body.participant_id, body.meal)
    return {"ok": True}


@app.post("/rooms/{code}/start")
async def start(code: str, body: Actor):
    room = rooms.get_room(code)
    rooms.require_host(room, body.participant_id)
    rooms.require_stage(room, "settings")
    catalog = await get_catalog()
    histories = await history.for_room(room, catalog)
    rooms.start(room, body.participant_id, catalog, histories, history.group_prior(histories))
    demo.ensure_bots_running(room)
    return {"ok": True}


@app.post("/rooms/{code}/demo-friends")
async def demo_friends(code: str, body: DemoFriends):
    room = rooms.get_room(code)
    rooms.require_host(room, body.participant_id)
    if not config.demo_enabled():
        raise ApiError(403, "Demo friends are turned off (start the backend with DEMO=1).")
    added = demo.add_friends(room, body.count, body.scenario, await get_catalog())
    return {"ok": True, "added": [{"id": p.id, "name": p.name} for p in added]}


# ── Leaving and starting over ────────────────────────────────────────────────
@app.post("/rooms/{code}/leave")
async def leave(code: str, body: Actor):
    rooms.remove_participant(rooms.get_room(code), body.participant_id, body.participant_id)
    return {"ok": True}


@app.post("/rooms/{code}/kick")
async def kick(code: str, body: Kick):
    """Host removes someone who is stuck (closed their phone, left the room) so the others can go on."""
    rooms.remove_participant(rooms.get_room(code), body.participant_id, body.target_id)
    return {"ok": True}


@app.post("/rooms/{code}/restart")
async def restart(code: str, body: Actor):
    """Host: new round with the same people (use after 'no match', or to try another meal)."""
    rooms.restart(rooms.get_room(code), body.participant_id)
    return {"ok": True}


@app.post("/rooms/{code}/retry")
async def retry(code: str, body: Actor):
    """Host: run the matching again after it failed."""
    engine.retry(rooms.get_room(code), body.participant_id)
    return {"ok": True}


# ── Swiping ──────────────────────────────────────────────────────────────────
@app.get("/rooms/{code}/cards")
async def cards(code: str, participant_id: str):
    return rooms.cards_for(rooms.get_room(code), participant_id)


@app.post("/rooms/{code}/swipe")
async def swipe(code: str, body: Swipe):
    return rooms.swipe(rooms.get_room(code), body.participant_id, body.level, body.card_id, body.liked)


# ── Disputes ─────────────────────────────────────────────────────────────────
@app.post("/rooms/{code}/dispute/start")
async def dispute_start(code: str, body: Actor):
    dispute.start_early(rooms.get_room(code), body.participant_id)
    return {"ok": True}


@app.post("/rooms/{code}/dispute/vote")
async def dispute_vote(code: str, body: Vote):
    dispute.cast_vote(rooms.get_room(code), body.participant_id, body.method)
    return {"ok": True}


@app.post("/rooms/{code}/dispute/spin")
async def dispute_spin(code: str, body: Actor):
    dispute.spin(rooms.get_room(code), body.participant_id)
    return {"ok": True}


@app.post("/rooms/{code}/dispute/move")
async def dispute_move(code: str, body: Move):
    dispute.move(rooms.get_room(code), body.participant_id, body.restaurant_id)
    return {"ok": True}


@app.post("/rooms/{code}/dispute/confirm")
async def dispute_confirm(code: str, body: Actor):
    dispute.confirm(rooms.get_room(code), body.participant_id)
    return {"ok": True}


# ── Result ───────────────────────────────────────────────────────────────────
@app.get("/rooms/{code}/result")
async def result(code: str):
    room = rooms.get_room(code)
    if room.result is None:
        raise ApiError(409, "No result yet.")
    return room.result


@app.post("/rooms/{code}/order")
async def order_endpoint(code: str, body: Actor):
    """Host: send everyone to the chosen restaurant (their own, after a split) in Careem to start a group order."""
    return await order.create_orders(rooms.get_room(code), body.participant_id)


# ── The app itself ───────────────────────────────────────────────────────────
# If the Flutter web build exists, serve it from the same address as the API. Then a friend only needs one
# URL, join links work, and there are no cross-origin problems.
#   cd app && flutter build web --release --dart-define=API_BASE=http://<this machine's address>:8000
_WEB = Path(os.getenv("WEB_DIR") or Path(__file__).resolve().parent.parent / "app" / "build" / "web")
if _WEB.is_dir():
    app.mount("/", StaticFiles(directory=_WEB, html=True), name="web")  # must stay LAST: API routes win
