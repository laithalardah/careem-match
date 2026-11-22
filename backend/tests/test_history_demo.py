"""History weights and demo friends (bots)."""
import asyncio
import time

import history
import rooms
from catalog import load_cache, Catalog


def catalog():
    return Catalog(load_cache(), "cache")


def test_weigh_is_recency_weighted_and_normalised():
    cat = catalog()
    orders = [
        {"restaurant_id": 30101, "restaurant_name": "Shawarma Station", "days_ago": 0, "items": []},
        {"restaurant_id": 30103, "restaurant_name": "Pizza Piazza", "days_ago": 30, "items": []},
    ]
    h = history.weigh(orders, cat, "mcp")
    assert h.restaurant[30101] == 1.0
    assert abs(h.restaurant[30103] - 0.5) < 1e-9  # one half-life old
    assert h.category["Shawarma"] == 1.0 and abs(h.category["Pizza"] - 0.5) < 1e-9


def test_repeat_orders_add_up():
    cat = catalog()
    once = [{"restaurant_id": 30101, "restaurant_name": "", "days_ago": 5, "items": []},
            {"restaurant_id": 30103, "restaurant_name": "", "days_ago": 5, "items": []}]
    twice = once + [{"restaurant_id": 30101, "restaurant_name": "", "days_ago": 5, "items": []}]
    assert history.weigh(once, cat, "x").restaurant[30101] == history.weigh(once, cat, "x").restaurant[30103]
    assert history.weigh(twice, cat, "x").restaurant[30101] > history.weigh(twice, cat, "x").restaurant[30103]


def test_parse_activities_skips_non_food_and_computes_age():
    from datetime import datetime, timezone

    now = datetime(2026, 11, 22, tzinfo=timezone.utc)
    acts = [
        {"type": "food", "created_at": "2026-11-12T00:00:00Z",
         "data": {"merchant_id": 30101, "merchant_name": "Shawarma Station", "items": [{"name": "Wrap"}]}},
        {"type": "ride", "created_at": "2026-11-12T00:00:00Z", "data": {}},
    ]
    out = history.parse_activities(acts, now)
    assert len(out) == 1 and round(out[0]["days_ago"]) == 10 and out[0]["items"] == ["Wrap"]


def test_demo_friends_endpoint(h, client):
    code, host = h.room()
    r = client.post(f"/rooms/{code}/demo-friends", json={"participant_id": host, "count": 3, "scenario": "dispute"})
    assert r.status_code == 200
    s = h.state(code)
    bots = [p for p in s["participants"] if p["is_bot"]]
    assert len(bots) == 3 and not any(p["is_bot"] for p in s["participants"] if p["is_host"])
    assert len({p["name"] for p in s["participants"]}) == 4


def test_demo_friends_rules(h, client, monkeypatch):
    code, host = h.room()
    guest = h.join(code, "Real")
    assert client.post(f"/rooms/{code}/demo-friends", json={"participant_id": guest, "count": 1}).status_code == 403
    assert client.post(f"/rooms/{code}/demo-friends", json={"participant_id": host, "count": 5}).status_code == 422
    monkeypatch.setenv("DEMO", "0")
    assert client.post(f"/rooms/{code}/demo-friends", json={"participant_id": host, "count": 1}).status_code == 403
    assert client.get("/health").json()["demo"] is False


def test_scenario_personas(h, client):
    code, host = h.room()
    client.post(f"/rooms/{code}/demo-friends", json={"participant_id": host, "count": 4, "scenario": "dispute"})
    room = rooms.ROOMS[code]
    bots = [p.persona for p in room.participants.values() if p.is_bot]
    loves = [tuple(b["loves"]) for b in bots]
    assert len(set(loves)) == 2  # two camps
    for b in bots:
        assert b["dislikes"] and set(b["dislikes"]).isdisjoint(b["loves"])
    code2, host2 = h.room()
    client.post(f"/rooms/{code2}/demo-friends", json={"participant_id": host2, "count": 3, "scenario": "consensus"})
    loves2 = {tuple(p.persona["loves"]) for p in rooms.ROOMS[code2].participants.values() if p.is_bot}
    assert len(loves2) == 1


def test_bots_swipe_by_themselves_and_use_history(h, client):
    code, host = h.room()
    client.post(f"/rooms/{code}/demo-friends", json={"participant_id": host, "count": 2, "scenario": "consensus"})
    h.start_swiping(code, host, "lunch")
    # real history sorted the cards: host history has Shawarma and Pizza, so those come first
    titles = [c["title"] for c in h.cards(code, host)["cards"]]
    assert titles[0] in ("Shawarma", "Pizza")
    # bots swipe the whole level without the host doing anything
    deadline = time.time() + 5
    while time.time() < deadline:
        bots = [p for p in h.state(code)["participants"] if p["is_bot"]]
        if all(p["progress"]["done"] for p in bots):
            break
        time.sleep(0.05)
    assert all(p["progress"]["done"] for p in bots)
    # the level has NOT advanced: the host still has to swipe
    assert h.state(code)["level"] == "category"
    room = rooms.ROOMS[code]
    assert {hh.source for pid, hh in room.history.items() if room.participants[pid].is_bot} == {"demo"}
    assert room.history[host].source == "cache"
