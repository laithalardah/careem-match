"""Careem Match backend: FastAPI app implementing API v2.1 (see docs/v2-plan.md).

Run:  DEMO=1 uvicorn main:app --host 0.0.0.0 --port 8000
All state-changing handlers are `async def`, so room mutations run on the event loop and never race.
"""
from __future__ import annotations

from typing import Literal

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

import config
import engine  # noqa: F401  (registers the matching hook)
import rooms
from catalog import get_catalog
from rooms import ApiError

app = FastAPI(title="Careem Match", version="2.1")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


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
    rooms.start(room, body.participant_id, catalog)
    return {"ok": True}


# ── Swiping ──────────────────────────────────────────────────────────────────
@app.get("/rooms/{code}/cards")
async def cards(code: str, participant_id: str):
    return rooms.cards_for(rooms.get_room(code), participant_id)


@app.post("/rooms/{code}/swipe")
async def swipe(code: str, body: Swipe):
    return rooms.swipe(rooms.get_room(code), body.participant_id, body.level, body.card_id, body.liked)


# ── Result ───────────────────────────────────────────────────────────────────
@app.get("/rooms/{code}/result")
async def result(code: str):
    room = rooms.get_room(code)
    if room.result is None:
        raise ApiError(409, "No result yet.")
    return room.result
