"""Consensus vs dispute, voting, wheel and split."""
import time

import dispute
import rooms

ALL = {"Shawarma", "Pizza", "Sushi", "Healthy"}


def wait_for(cond, timeout=5.0):
    end = time.time() + timeout
    while time.time() < end:
        if cond():
            return True
        time.sleep(0.02)
    return False


def play(h, picks: dict[str, set[str]], *, finish_restaurants=True):
    """picks: player name -> restaurant titles they like at level 2 (everyone likes all categories).
    The first player is the host. Returns (code, {name: pid})."""
    names = list(picks)
    code, host = h.room(host=names[0])
    pids = {names[0]: host}
    for n in names[1:]:
        pids[n] = h.join(code, n)
    h.start_swiping(code, host, "lunch")
    for pid in pids.values():
        h.swipe_all(code, pid, lambda c: True)
    assert h.state(code)["level"] == "restaurant"
    for n, pid in pids.items():
        if finish_restaurants or n == names[0]:
            h.swipe_all(code, pid, lambda c, n=n: c["title"] in picks[n])
    return code, pids


# ── Consensus vs dispute ─────────────────────────────────────────────────────
def test_majority_is_consensus_no_dispute(h):
    code, _ = play(h, {"A": {"Shawarma Station"}, "B": {"Shawarma Station"}, "C": {"Shawarma Station"}, "D": {"Pizza Piazza"}})
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    res = h.c.get(f"/rooms/{code}/result").json()
    assert res["resolution"]["type"] == "consensus" and res["groups"][0]["restaurant"]["name"] == "Shawarma Station"


def test_two_versus_two_is_a_dispute(h):
    code, pids = play(h, {"A": {"Shawarma Station"}, "B": {"Shawarma Station"}, "C": {"Pizza Piazza"}, "D": {"Pizza Piazza"}})
    s = h.state(code)
    assert s["stage"] == "dispute" and s["dispute"]["reason"] == "no_consensus"
    cs = {c["name"]: c for c in s["dispute"]["contenders"]}
    assert set(cs) == {"Shawarma Station", "Pizza Piazza"}
    assert sorted(cs["Shawarma Station"]["supporter_ids"]) == sorted([pids["A"], pids["B"]])
    assert sorted(cs["Pizza Piazza"]["supporter_ids"]) == sorted([pids["C"], pids["D"]])
    assert cs["Pizza Piazza"]["cuisine"] == "Pizza" and cs["Pizza Piazza"]["image_url"]


def test_three_way_split(h):
    picks = {"A": {"Shawarma Station"}, "B": {"Shawarma Station"}, "C": {"Pizza Piazza"}, "D": {"Pizza Piazza"},
             "E": {"Sakura Sushi Lab"}, "F": {"Sakura Sushi Lab"}}
    code, _ = play(h, picks)
    s = h.state(code)
    assert s["stage"] == "dispute" and len(s["dispute"]["contenders"]) == 3


def test_veto_blocks_a_majority(h):
    # B and C like Shawarma Station, but A skipped both it and its category -> not consensus
    code, host = h.room(host="A")
    b, c = h.join(code, "B"), h.join(code, "C")
    h.start_swiping(code, host, "lunch")
    h.swipe_all(code, host, lambda card: card["title"] != "Shawarma")
    h.swipe_all(code, b, lambda card: True)
    h.swipe_all(code, c, lambda card: True)
    h.swipe_all(code, host, lambda card: card["title"] == "Pizza Piazza")
    h.swipe_all(code, b, lambda card: card["title"] == "Shawarma Station")
    h.swipe_all(code, c, lambda card: card["title"] == "Shawarma Station")
    s = h.state(code)
    assert s["stage"] == "dispute"
    assert {x["name"] for x in s["dispute"]["contenders"]} == {"Shawarma Station", "Pizza Piazza"}


def test_nobody_likes_a_restaurant_is_no_match(h):
    code, _ = play(h, {"A": set(), "B": set()})
    assert h.state(code)["stage"] == "result"
    assert h.c.get(f"/rooms/{code}/result").json()["status"] == "no_match"


def test_single_favourite_below_the_bar_is_a_compromise(h):
    picks = {"A": {"Shawarma Station"}, "B": {"Shawarma Station"}, "C": set(), "D": set(), "E": set()}
    code, _ = play(h, picks)
    assert wait_for(lambda: h.state(code)["stage"] == "result")  # no dispute: only one camp
    assert h.c.get(f"/rooms/{code}/result").json()["groups"][0]["restaurant"]["name"] == "Shawarma Station"


# ── Voting ───────────────────────────────────────────────────────────────────
def two_v_two(h):
    return play(h, {"A": {"Shawarma Station"}, "B": {"Shawarma Station"}, "C": {"Pizza Piazza"}, "D": {"Pizza Piazza"}})


def vote(h, code, pid, method):
    return h.c.post(f"/rooms/{code}/dispute/vote", json={"participant_id": pid, "method": method})


def test_majority_vote_wins_immediately(h):
    code, p = two_v_two(h)
    assert vote(h, code, p["A"], "wheel").status_code == 200
    assert h.state(code)["dispute"]["method"] is None
    vote(h, code, p["B"], "wheel")
    assert h.state(code)["dispute"]["method"] is None  # 2 of 4 is not a majority
    vote(h, code, p["C"], "wheel")
    d = h.state(code)["dispute"]
    assert d["method"] == "wheel" and d["wheel"]["spin_id"] is None and len(d["wheel"]["segments"]) == 2


def test_tie_is_broken_by_the_host_vote(h):
    code, p = two_v_two(h)
    vote(h, code, p["B"], "wheel")
    vote(h, code, p["C"], "wheel")
    vote(h, code, p["D"], "split")
    assert h.state(code)["dispute"]["method"] is None  # waiting for the host
    vote(h, code, p["A"], "split")  # 2-2, host says split
    assert h.state(code)["dispute"]["method"] == "split"


def test_vote_errors(h):
    code, p = two_v_two(h)
    assert vote(h, code, "p_x", "wheel").status_code == 403
    assert h.c.post(f"/rooms/{code}/dispute/vote", json={"participant_id": p["A"], "method": "coin"}).status_code == 422
    for n in "ABC":
        vote(h, code, p[n], "wheel")
    assert vote(h, code, p["D"], "split").status_code == 409  # already decided


# ── Wheel ────────────────────────────────────────────────────────────────────
def to_wheel(h):
    code, p = two_v_two(h)
    for n in "ABC":
        vote(h, code, p[n], "wheel")
    return code, p


def spin(h, code, pid):
    return h.c.post(f"/rooms/{code}/dispute/spin", json={"participant_id": pid})


def test_spin_rules_and_result(h):
    code, p = to_wheel(h)
    assert spin(h, code, p["B"]).status_code == 403  # host only
    assert spin(h, code, p["A"]).status_code == 200
    assert spin(h, code, p["A"]).status_code == 409  # only once
    w = h.state(code)["dispute"]["wheel"]
    assert w["spin_id"] and w["duration_ms"] == 40 and 0 <= w["final_angle_deg"] < 360
    assert w["winner_restaurant_id"] in {s["restaurant_id"] for s in w["segments"]}
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    res = h.c.get(f"/rooms/{code}/result").json()
    assert res["resolution"]["type"] == "wheel" and res["groups"][0]["restaurant"]["id"] == w["winner_restaurant_id"]
    assert len(res["groups"][0]["participant_ids"]) == 4  # the wheel decides for everyone


def test_spin_needs_the_wheel_method(h):
    code, p = two_v_two(h)
    assert spin(h, code, p["A"]).status_code == 409


def test_wheel_draw_follows_the_weights():
    n, wins = 4000, 0
    for _ in range(n):
        wins += dispute.draw_winner([3.0, 1.0]) == 0
    assert abs(wins / n - 0.75) < 0.04


def test_landing_angle_puts_the_winner_under_the_pointer():
    weights = [3.0, 1.0, 2.0]
    total = sum(weights)
    for index in range(3):
        start = sum(weights[:index]) / total * 360
        end = start + weights[index] / total * 360
        for _ in range(200):
            under_pointer = (360 - dispute.landing_angle(weights, index)) % 360
            assert start <= under_pointer <= end


# ── Split ────────────────────────────────────────────────────────────────────
def to_split(h):
    code, p = two_v_two(h)
    for n in "ABC":
        vote(h, code, p[n], "split")
    return code, p


def move(h, code, pid, rid):
    return h.c.post(f"/rooms/{code}/dispute/move", json={"participant_id": pid, "restaurant_id": rid})


def test_split_move_and_confirm(h):
    code, p = to_split(h)
    groups = h.state(code)["dispute"]["split"]["groups"]
    assert len(groups) == 2 and h.state(code)["dispute"]["split"]["confirmed"] is False
    shaw = next(g["restaurant_id"] for g in groups if g["name"] == "Shawarma Station")
    pizza = next(g["restaurant_id"] for g in groups if g["name"] == "Pizza Piazza")
    assert move(h, code, p["D"], shaw).status_code == 200  # D switches camp
    g = {x["name"]: x["participant_ids"] for x in h.state(code)["dispute"]["split"]["groups"]}
    assert sorted(g["Shawarma Station"]) == sorted([p["A"], p["B"], p["D"]]) and g["Pizza Piazza"] == [p["C"]]
    assert move(h, code, p["D"], 999).status_code == 422
    assert h.c.post(f"/rooms/{code}/dispute/confirm", json={"participant_id": p["B"]}).status_code == 403
    assert h.c.post(f"/rooms/{code}/dispute/confirm", json={"participant_id": p["A"]}).status_code == 200
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    res = h.c.get(f"/rooms/{code}/result").json()
    assert res["resolution"]["type"] == "split" and len(res["groups"]) == 2
    assert res["restaurant"] is None  # top-level mirror is empty when split
    assert move(h, code, p["A"], pizza).status_code == 409  # too late


def test_an_empty_group_vanishes_and_one_group_is_a_consensus(h):
    code, p = to_split(h)
    groups = h.state(code)["dispute"]["split"]["groups"]
    shaw = next(g["restaurant_id"] for g in groups if g["name"] == "Shawarma Station")
    move(h, code, p["C"], shaw)
    assert len(h.state(code)["dispute"]["split"]["groups"]) == 2
    move(h, code, p["D"], shaw)  # Pizza Piazza is now empty -> everyone is together
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    res = h.c.get(f"/rooms/{code}/result").json()
    assert res["resolution"]["type"] == "consensus" and len(res["groups"]) == 1
    assert res["restaurant"]["name"] == "Shawarma Station"


# ── Early dispute ────────────────────────────────────────────────────────────
def early(h, code, pid):
    return h.c.post(f"/rooms/{code}/dispute/start", json={"participant_id": pid})


def test_host_can_ask_for_help_early(h):
    # host and B finished and disagree; C has not swiped yet
    code, host = h.room(host="A")
    b, c = h.join(code, "B"), h.join(code, "C")
    h.start_swiping(code, host, "lunch")
    for pid in (host, b, c):
        h.swipe_all(code, pid, lambda card: True)
    assert early(h, code, b).status_code == 403
    h.swipe_all(code, host, lambda card: card["title"] == "Shawarma Station")
    h.swipe_all(code, b, lambda card: card["title"] == "Pizza Piazza")
    assert h.state(code)["stage"] == "swiping"  # C is still swiping
    r = early(h, code, host)
    assert r.status_code == 200
    s = h.state(code)
    assert s["stage"] == "dispute" and s["dispute"]["reason"] == "host_requested"
    assert {x["name"] for x in s["dispute"]["contenders"]} == {"Shawarma Station", "Pizza Piazza"}


def test_early_help_needs_enough_swipes_and_a_disagreement(h):
    code, host = h.room(host="A")
    b = h.join(code, "B")
    h.start_swiping(code, host, "lunch")
    h.swipe_all(code, host, lambda card: True)
    h.swipe_all(code, b, lambda card: True)
    assert early(h, code, host).status_code == 409  # no restaurant swipes yet
    h.swipe_all(code, host, lambda card: card["title"] == "Shawarma Station")
    assert early(h, code, host).status_code == 409  # B has not swiped: no disagreement visible
