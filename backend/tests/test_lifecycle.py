"""Leaving, kicking, restarting, retrying, the default meal, the order for guests, and serving the app."""
import dispute
import rooms
from catalog import Catalog, load_cache
from fakes import install
from test_dispute import play, wait_for

CATALOG = Catalog(load_cache(), "cache")
TWO_V_TWO = {"A": {"Shawarma Station"}, "B": {"Shawarma Station"}, "C": {"Pizza Piazza"}, "D": {"Pizza Piazza"}}


def post(h, path, **body):
    return h.c.post(path, json=body)


# ── default meal ─────────────────────────────────────────────────────────────
def test_starting_without_picking_a_meal_uses_dinner(h):
    code, host = h.room()
    h.join(code, "B")
    post(h, f"/rooms/{code}/next", participant_id=host)
    assert post(h, f"/rooms/{code}/start", participant_id=host).status_code == 200
    s = h.state(code)
    assert s["stage"] == "swiping" and s["settings"]["meal"] == "dinner"


# ── leave and kick ───────────────────────────────────────────────────────────
def test_a_guest_can_leave_the_lobby(h):
    code, host = h.room()
    b = h.join(code, "B")
    assert post(h, f"/rooms/{code}/leave", participant_id=b).status_code == 200
    assert [p["name"] for p in h.state(code)["participants"]] == ["Host"]
    assert post(h, f"/rooms/{code}/leave", participant_id=b).status_code == 403  # already gone


def test_the_host_cannot_leave_and_guests_cannot_kick(h):
    code, host = h.room()
    b = h.join(code, "B")
    c = h.join(code, "C")
    assert post(h, f"/rooms/{code}/leave", participant_id=host).status_code == 409
    assert post(h, f"/rooms/{code}/kick", participant_id=b, target_id=c).status_code == 403
    assert post(h, f"/rooms/{code}/kick", participant_id=host, target_id=host).status_code == 409
    assert post(h, f"/rooms/{code}/kick", participant_id=host, target_id="p_nope").status_code == 404


def test_kicking_the_stuck_person_lets_everyone_else_move_on(h):
    code, host = h.room(host="A")
    b = h.join(code, "B")
    stuck = h.join(code, "C")
    h.start_swiping(code, host, "lunch")
    for pid in (host, b):
        h.swipe_all(code, pid, lambda c: True)
    assert h.state(code)["level"] == "category"  # C never swiped, so everybody waits
    assert post(h, f"/rooms/{code}/kick", participant_id=host, target_id=stuck).status_code == 200
    assert h.state(code)["level"] == "restaurant"
    assert [p["name"] for p in h.state(code)["participants"]] == ["A", "B"]


def test_leaving_during_the_last_level_finishes_the_match(h):
    code, host = h.room(host="A")
    b = h.join(code, "B")
    c = h.join(code, "C")
    h.start_swiping(code, host, "lunch")
    for pid in (host, b, c):
        h.swipe_all(code, pid, lambda card: True)
    for pid in (host, b):
        h.swipe_all(code, pid, lambda card: card["title"] == "Shawarma Station")
    assert h.state(code)["stage"] == "swiping"
    assert post(h, f"/rooms/{code}/leave", participant_id=c).status_code == 200
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    assert h.c.get(f"/rooms/{code}/result").json()["status"] == "ready"


def test_leaving_a_dispute_updates_it(h):
    code, p = play(h, TWO_V_TWO)
    assert h.state(code)["stage"] == "dispute"
    assert post(h, f"/rooms/{code}/leave", participant_id=p["B"]).status_code == 200
    d = h.state(code)["dispute"]
    shaw = next(c for c in d["contenders"] if c["name"] == "Shawarma Station")
    assert shaw["supporter_ids"] == [p["A"]] and len(d["contenders"]) == 2


def test_if_one_camp_leaves_the_other_wins(h):
    code, p = play(h, TWO_V_TWO)
    post(h, f"/rooms/{code}/leave", participant_id=p["C"])
    assert h.state(code)["stage"] == "dispute"
    post(h, f"/rooms/{code}/leave", participant_id=p["D"])
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    res = h.c.get(f"/rooms/{code}/result").json()
    assert res["resolution"]["type"] == "consensus" and res["restaurant"]["name"] == "Shawarma Station"


def test_cannot_leave_once_matching_started(h):
    code, p = play(h, {"A": {"Shawarma Station"}, "B": {"Shawarma Station"}, "C": {"Shawarma Station"}})
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    assert post(h, f"/rooms/{code}/leave", participant_id=p["C"]).status_code == 409


# ── restart ──────────────────────────────────────────────────────────────────
def test_restart_after_no_match_keeps_the_people(h):
    code, p = play(h, {"A": set(), "B": set()})
    assert h.state(code)["stage"] == "result"
    assert post(h, f"/rooms/{code}/restart", participant_id=p["B"]).status_code == 403
    assert post(h, f"/rooms/{code}/restart", participant_id=p["A"]).status_code == 200
    s = h.state(code)
    assert s["stage"] == "settings" and s["level"] is None and s["dispute"] is None and s["order"] is None
    assert [x["name"] for x in s["participants"]] == ["A", "B"]
    assert all(x["progress"]["swiped"] == 0 for x in s["participants"])
    assert h.c.get(f"/rooms/{code}/result").status_code == 409  # result is cleared
    # and a second round works
    assert post(h, f"/rooms/{code}/start", participant_id=p["A"]).status_code == 200
    assert h.state(code)["stage"] == "swiping"


def test_restart_from_a_dispute_cancels_the_wheel(h):
    code, p = play(h, TWO_V_TWO)
    for n in "ABC":
        post(h, f"/rooms/{code}/dispute/vote", participant_id=p[n], method="wheel")
    post(h, f"/rooms/{code}/dispute/spin", participant_id=p["A"])
    assert post(h, f"/rooms/{code}/restart", participant_id=p["A"]).status_code == 200
    import time
    time.sleep(0.3)  # the cancelled wheel must not push the room into matching
    assert h.state(code)["stage"] == "settings"


def test_restart_needs_something_to_restart(h):
    code, host = h.room()
    h.join(code, "B")
    assert post(h, f"/rooms/{code}/restart", participant_id=host).status_code == 409


# ── retry ────────────────────────────────────────────────────────────────────
def test_retry_reruns_a_failed_match(h, monkeypatch):
    import planner

    install(monkeypatch, CATALOG, fail={30101: -1})
    code, p = play(h, {n: {"Shawarma Station"} for n in "AB"})
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    assert h.c.get(f"/rooms/{code}/result").json()["status"] == "failed"
    assert post(h, f"/rooms/{code}/retry", participant_id=p["B"]).status_code == 403
    monkeypatch.setattr(planner, "GATEWAY_FACTORY", None)  # the outage is over
    assert post(h, f"/rooms/{code}/retry", participant_id=p["A"]).status_code == 200
    assert wait_for(lambda: h.c.get(f"/rooms/{code}/result").json()["status"] == "ready")
    assert post(h, f"/rooms/{code}/retry", participant_id=p["A"]).status_code == 409  # nothing left to retry


# ── guests see the order ─────────────────────────────────────────────────────
def test_guests_can_read_the_order_from_the_room(h):
    code, p = play(h, {n: {"Shawarma Station"} for n in "ABC"})
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    assert h.state(code, p["B"])["order"] is None
    post(h, f"/rooms/{code}/order", participant_id=p["A"])
    s = h.state(code, p["B"])
    assert s["stage"] == "ordered" and s["order"]["status"] == "go"
    assert s["order"]["groups"][0]["restaurant_link"] and s["order"]["message"]


# ── CORS and the app ─────────────────────────────────────────────────────────
def test_the_date_header_is_exposed_to_browsers(client):
    # (the real server adds the Date header itself; browsers only let the app read it when it is exposed)
    r = client.get("/health", headers={"Origin": "http://192.168.1.20:8000"})
    assert "Date" in r.headers["access-control-expose-headers"]


def test_the_app_is_served_from_the_same_address(client):
    r = client.get("/")
    assert r.status_code == 200 and "app-stub" in r.text
    assert client.get("/health").json()["status"] == "ok"  # the API still wins
    assert client.get("/rooms/NOPE12").status_code == 404 and "detail" in client.get("/rooms/NOPE12").json()
