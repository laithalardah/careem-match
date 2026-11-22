import os

# Offline, deterministic: cached catalog, no Bedrock, instant bots. Set before app modules read config.
os.environ["FALLBACK"] = "1"
os.environ["AGENT_MODE"] = "planner"
os.environ["DEMO"] = "1"
os.environ["BOT_MIN_DELAY"] = "0"
os.environ["BOT_MAX_DELAY"] = "0"
os.environ["WHEEL_DURATION_MS"] = "40"
os.environ["WEB_DIR"] = os.path.join(os.path.dirname(__file__), "web_stub")
os.environ["WHEEL_REVEAL_PAUSE_MS"] = "40"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

import catalog  # noqa: E402
import rooms  # noqa: E402


@pytest.fixture()
def client():
    from main import app

    rooms.ROOMS.clear()
    catalog.reset_catalog()
    with TestClient(app) as c:
        yield c


class Helper:
    """Small helpers to drive the API in tests."""

    def __init__(self, client):
        self.c = client

    def room(self, mode="food", host="Host"):
        r = self.c.post("/rooms", json={"mode": mode, "host_name": host}).json()
        return r["room_code"], r["participant_id"]

    def join(self, code, name):
        return self.c.post(f"/rooms/{code}/join", json={"name": name}).json()["participant_id"]

    def state(self, code, pid=None):
        return self.c.get(f"/rooms/{code}", params={"participant_id": pid} if pid else None).json()

    def start_swiping(self, code, host, meal="lunch"):
        assert self.c.post(f"/rooms/{code}/next", json={"participant_id": host}).status_code == 200
        assert self.c.put(f"/rooms/{code}/settings", json={"participant_id": host, "meal": meal}).status_code == 200
        r = self.c.post(f"/rooms/{code}/start", json={"participant_id": host})
        assert r.status_code == 200, r.text

    def cards(self, code, pid):
        return self.c.get(f"/rooms/{code}/cards", params={"participant_id": pid}).json()

    def swipe_all(self, code, pid, like):
        """like: callable(card) -> bool"""
        data = self.cards(code, pid)
        for card in data["cards"]:
            r = self.c.post(f"/rooms/{code}/swipe", json={
                "participant_id": pid, "level": data["level"], "card_id": card["id"], "liked": bool(like(card))})
            assert r.status_code == 200, r.text


@pytest.fixture()
def h(client):
    return Helper(client)
