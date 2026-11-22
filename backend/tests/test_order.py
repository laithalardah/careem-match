"""The hand-off to Careem's group order: host button, links, no ordering by us at all."""
import re
from pathlib import Path

from test_dispute import play, wait_for

CONSENSUS = {"A": {"Shawarma Station"}, "B": {"Shawarma Station"}, "C": {"Shawarma Station"}}
SPLIT = {"A": {"Shawarma Station"}, "B": {"Shawarma Station"}, "C": {"Pizza Piazza"}, "D": {"Pizza Piazza"}}


def ready(h, who=CONSENSUS):
    code, pids = play(h, who)
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    return code, pids


def go(h, code, pid):
    return h.c.post(f"/rooms/{code}/order", json={"participant_id": pid})


def test_only_the_host_can_continue_and_only_after_a_result(h):
    code, host = h.room(host="A")
    h.join(code, "B")
    assert go(h, code, host).status_code == 409  # no restaurant yet
    code, pids = ready(h)
    assert go(h, code, pids["B"]).status_code == 403
    assert go(h, code, "p_x").status_code == 403
    assert h.state(code)["stage"] == "result"


def test_host_continue_sends_everyone_to_the_restaurant(h):
    code, pids = ready(h)
    r = go(h, code, pids["A"])
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "go" and h.state(code)["stage"] == "ordered"
    g = body["groups"][0]
    assert g["status"] == "go" and g["restaurant_link"] == "careemfood://restaurants/30101"
    assert g["restaurant_name"] == "Shawarma Station" and g["price_breakdown"] is None
    assert "group order" in g["message"] and "A, B and C" in g["message"] and "own dishes" in g["message"]
    assert "Shawarma Station" in body["message"]


def test_everyone_sees_the_hand_off_in_the_room(h):
    code, pids = ready(h)
    assert h.state(code, pids["B"])["order"] is None
    go(h, code, pids["A"])
    s = h.state(code, pids["B"])  # a guest, not the host
    assert s["stage"] == "ordered" and s["order"]["status"] == "go" and s["order"]["groups"][0]["restaurant_link"]


def test_a_second_tap_changes_nothing(h):
    code, pids = ready(h)
    first = go(h, code, pids["A"]).json()
    assert go(h, code, pids["A"]).json() == first


def test_a_split_sends_each_group_to_its_own_restaurant(h):
    code, p = play(h, SPLIT)
    for n in "ABC":
        h.c.post(f"/rooms/{code}/dispute/vote", json={"participant_id": p[n], "method": "split"})
    h.c.post(f"/rooms/{code}/dispute/confirm", json={"participant_id": p["A"]})
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    body = go(h, code, p["A"]).json()
    links = {g["restaurant_name"]: g["restaurant_link"] for g in body["groups"]}
    assert links == {"Shawarma Station": "careemfood://restaurants/30101", "Pizza Piazza": "careemfood://restaurants/30103"}
    assert "own restaurant" in body["message"]
    msgs = {g["restaurant_name"]: g["message"] for g in body["groups"]}
    assert "A and B" in msgs["Shawarma Station"] and "C and D" in msgs["Pizza Piazza"]


def test_dine_out_uses_the_same_hand_off(h):
    code, host = h.room(mode="dineout", host="A")
    b = h.join(code, "B")
    h.start_swiping(code, host, "lunch")
    for pid in (host, b):
        h.swipe_all(code, pid, lambda c: True)
    for pid in (host, b):
        h.swipe_all(code, pid, lambda c: c["title"] == "Shawarma Station")
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    body = go(h, code, host).json()
    assert body["status"] == "go" and body["groups"][0]["restaurant_link"]


def test_nothing_in_the_backend_orders_or_changes_a_cart():
    root = Path(__file__).resolve().parent.parent
    for name in ("order.py", "planner.py", "agent.py", "engine.py", "main.py"):
        src = (root / name).read_text(encoding="utf-8")
        assert not re.search(r"cart_\w+|checkout|\bcreate_order\b|save_new_address|allow_mutating=True", src), name
    # the hand-off does not even talk to the MCP
    assert not re.search(r"import mcp|mcp_client|Careem\(", (root / "order.py").read_text(encoding="utf-8"))
