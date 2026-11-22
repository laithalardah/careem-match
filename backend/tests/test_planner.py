"""Deterministic planner: baskets, options, re-planning, retries, read-only."""
import re
from pathlib import Path

import planner
from catalog import Catalog, load_cache
from fakes import install
from test_dispute import play, wait_for

CATALOG = Catalog(load_cache(), "cache")
CONSENSUS = {"A": {"Shawarma Station"}, "B": {"Shawarma Station"}, "C": {"Shawarma Station"}, "D": {"Pizza Piazza"}}
BOTH = {n: {"Shawarma Station", "Pizza Piazza"} for n in "ABC"}


def result(h, code):
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    return h.c.get(f"/rooms/{code}/result").json()


def test_consensus_basket_with_required_options(h):
    code, pids = play(h, CONSENSUS)
    res = result(h, code)
    assert res["status"] == "ready" and res["resolution"]["type"] == "consensus"
    g = res["groups"][0]
    assert g["restaurant"]["name"] == "Shawarma Station" and g["currency"] == "AED" and g["restaurant"]["link"]
    assert len(g["basket"]) == 4 and {b["participant_id"] for b in g["basket"]} == set(pids.values())
    # the wrap needs a size: it must carry a chosen option, and prices include options
    wrap = [b for b in g["basket"] if b["dish_name"] == "Chicken Shawarma Wrap"]
    assert wrap and all(b["options"] for b in wrap)
    assert g["total_price"] == round(sum(b["price"] for b in g["basket"]), 2)
    # top-level fields mirror the single group
    assert res["restaurant"] == g["restaurant"] and res["basket"] == g["basket"] and res["total_price"] == g["total_price"]
    assert [p["name"] for p in g["per_person"]] == ["A", "B", "C", "D"]
    assert all(p["why"] for p in g["per_person"])
    assert res["reasoning"] == g["reasoning"] and "3 of 4" in g["reasoning"]


def test_a_group_does_not_get_four_of_the_same_dish(h):
    code, pids = play(h, CONSENSUS)
    basket = result(h, code)["groups"][0]["basket"]
    dishes = [b["dish_name"] for b in basket]
    # Shawarma Station has 3 dishes for 4 people: all three appear, only one repeats
    assert len(set(dishes)) == 3
    from collections import Counter
    assert max(Counter(dishes).values()) == 2


def test_history_decides_the_host_dish(h):
    code, pids = play(h, CONSENSUS)
    g = result(h, code)["groups"][0]
    host_line = next(b for b in g["basket"] if b["participant_id"] == pids["A"])
    assert host_line["dish_name"] in ("Chicken Shawarma Wrap", "Falafel Plate")  # host ordered these before
    why = next(p for p in g["per_person"] if p["participant_id"] == pids["A"])["why"]
    assert "ordered it before" in why


def test_scores_and_trace_are_present(h):
    code, _ = play(h, CONSENSUS)
    res = result(h, code)
    assert res["scores"] and {"restaurant_id", "restaurant_name", "group_score", "per_person"} <= set(res["scores"][0])
    tools = [s["tool"] for s in res["agent_trace"]]
    assert "cache:food_get_restaurant_menu" in tools and "cache:food_get_items_options" in tools and "plan" in tools
    assert [s["iteration"] for s in res["agent_trace"]] == list(range(1, len(tools) + 1))
    assert set(res["agent_trace"][0]) == {"iteration", "tool", "input", "output_summary", "failed", "group_id"}


def test_replans_when_the_first_restaurant_is_closed(h, monkeypatch):
    install(monkeypatch, CATALOG, close_first=True)
    code, _ = play(h, BOTH)
    res = result(h, code)
    assert res["status"] == "ready"
    failed = [s for s in res["agent_trace"] if s["failed"]]
    assert failed and "closed" in failed[0]["output_summary"].lower()
    assert any(s["tool"] == "replan" for s in res["agent_trace"])
    closed_name = re.match(r"(.+?) is closed", failed[0]["output_summary"]).group(1)
    assert res["groups"][0]["restaurant"]["name"] != closed_name


def test_transient_lookup_errors_are_retried(h, monkeypatch):
    # every restaurant fails twice, then works: retries recover, no re-plan needed
    install(monkeypatch, CATALOG, fail={30101: 2, 30103: 2})
    code, _ = play(h, BOTH)
    res = result(h, code)
    assert res["status"] == "ready"
    retried = [s for s in res["agent_trace"] if s["failed"] and "Retrying" in s["output_summary"]]
    assert len(retried) == 2
    assert not any(s["tool"] == "replan" for s in res["agent_trace"])


def test_persistent_failure_replans_to_the_next_restaurant(h, monkeypatch):
    install(monkeypatch, CATALOG, fail={30101: -1, 30103: -1})
    code, _ = play(h, {n: {"Shawarma Station", "Pizza Piazza", "Sakura Sushi Lab"} for n in "AB"})
    res = result(h, code)
    # shortlist has up to 3: the third (sushi) is the only one left standing
    assert res["status"] == "ready" and res["groups"][0]["restaurant"]["name"] == "Sakura Sushi Lab"
    assert sum(1 for s in res["agent_trace"] if s["failed"] and "Giving up" in s["output_summary"]) == 2


def test_everything_failing_gives_a_readable_failure(h, monkeypatch):
    install(monkeypatch, CATALOG, fail={30101: -1, 30103: -1})
    code, _ = play(h, BOTH)
    res = result(h, code)
    assert res["status"] == "failed" and "upstream unavailable" in res["reasoning"]
    assert res["groups"] == [] and res["restaurant"] is None


def test_total_outage_keeps_the_trace_and_a_readable_message(h, monkeypatch):
    # the real MCP session wraps escaping exceptions in an ExceptionGroup; the planner must not leak that
    install(monkeypatch, CATALOG, fail={30101: -1, 30103: -1}, wrap_exit=True)
    code, _ = play(h, BOTH)
    res = result(h, code)
    assert res["status"] == "failed"
    assert "TaskGroup" not in res["reasoning"] and "upstream unavailable" in res["reasoning"]
    assert [s for s in res["agent_trace"] if s["failed"]], "the failed lookups must stay visible in the trace"


def test_connection_failure_is_reported_not_crashed(h, monkeypatch):
    import planner

    class Down:
        async def __aenter__(self):
            raise ConnectionRefusedError("sandbox is down")

        async def __aexit__(self, *exc):
            return None

    monkeypatch.setattr(planner, "GATEWAY_FACTORY", lambda room: Down())
    code, _ = play(h, BOTH)
    res = result(h, code)
    assert res["status"] == "failed" and "unreachable" in res["reasoning"]
    assert any(s["tool"] == "connect" and s["failed"] for s in res["agent_trace"])


def test_dishes_with_unresolvable_required_options_are_skipped(h, monkeypatch):
    # every required option group is empty: dishes that need a choice cannot be ordered, the rest can
    install(monkeypatch, CATALOG, hollow=True)
    code, _ = play(h, {n: {"Shawarma Station"} for n in "AB"})
    res = result(h, code)
    assert res["status"] == "ready"
    names = {b["dish_name"] for b in res["basket"]}
    assert "Chicken Shawarma Wrap" not in names and names <= {"Falafel Plate", "Mixed Grill Platter"}
    assert all(not b["options"] for b in res["basket"])  # the planner never invents options


def test_a_restaurant_with_nothing_orderable_raises_so_the_planner_replans():
    import pytest
    from dataclasses import replace
    import planner
    from planner import PlanFailed, choose_dishes

    syrniki = CATALOG.by_id(30104)  # both of its dishes need a choice
    hollow = replace(syrniki, dishes=[replace(d, option_groups=[replace(g, options=[]) for g in d.option_groups]) for d in syrniki.dishes])

    class R:  # the bits of a room choose_dishes reads
        history = {}

    with pytest.raises(PlanFailed, match="no dishes that can be ordered"):
        choose_dishes(R(), hollow, ["p1"])


def test_dine_out_has_no_basket(h, client):
    code, host = h.room(mode="dineout", host="A")
    b = h.join(code, "B")
    h.start_swiping(code, host, "lunch")
    for pid in (host, b):
        h.swipe_all(code, pid, lambda c: True)
    for pid in (host, b):
        h.swipe_all(code, pid, lambda c: c["title"] == "Shawarma Station")
    res = result(h, code)
    assert res["status"] == "ready" and res["basket"] == [] and res["total_price"] == 0
    assert res["restaurant"]["name"] == "Shawarma Station" and len(res["per_person"]) == 2


def test_split_gives_each_camp_its_own_basket(h):
    code, p = play(h, {"A": {"Shawarma Station"}, "B": {"Shawarma Station"}, "C": {"Pizza Piazza"}, "D": {"Pizza Piazza"}})
    for n in "ABC":
        h.c.post(f"/rooms/{code}/dispute/vote", json={"participant_id": p[n], "method": "split"})
    h.c.post(f"/rooms/{code}/dispute/confirm", json={"participant_id": p["A"]})
    res = result(h, code)
    assert res["resolution"]["type"] == "split" and len(res["groups"]) == 2 and res["restaurant"] is None
    by_name = {g["restaurant"]["name"]: g for g in res["groups"]}
    assert {b["participant_id"] for b in by_name["Shawarma Station"]["basket"]} == {p["A"], p["B"]}
    assert {b["participant_id"] for b in by_name["Pizza Piazza"]["basket"]} == {p["C"], p["D"]}
    assert [g["group_id"] for g in res["groups"]] == ["g1", "g2"]
    assert {s["group_id"] for s in res["agent_trace"]} == {"g1", "g2"}


def test_planner_never_uses_a_mutating_tool():
    src = (Path(planner.__file__).read_text(encoding="utf-8"))
    assert not re.search(r"cart_|checkout|create_order|save_new_address", src)
