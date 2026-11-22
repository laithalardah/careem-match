"""Deterministic planner: picks the restaurant, re-plans, retries, never orders."""
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


def test_consensus_gives_a_restaurant_and_no_basket(h):
    code, pids = play(h, CONSENSUS)
    res = result(h, code)
    assert res["status"] == "ready" and res["resolution"]["type"] == "consensus"
    g = res["groups"][0]
    assert g["restaurant"]["name"] == "Shawarma Station" and g["restaurant"]["link"] == "careemfood://restaurants/30101"
    assert g["participant_ids"] == list(pids.values())
    # everyone picks their own dishes in Careem's group order: no dishes and no prices from us
    assert g["basket"] == [] and g["total_price"] == 0 and g["currency"] == "AED"
    assert res["restaurant"] == g["restaurant"] and res["basket"] == []
    assert [p["name"] for p in g["per_person"]] == ["A", "B", "C", "D"] and all(p["why"] for p in g["per_person"])
    assert "3 of 4" in g["reasoning"] and "dish" not in g["reasoning"].lower()
    assert res["reasoning"] == g["reasoning"]


def test_per_person_reasons_come_from_votes_and_history(h):
    code, pids = play(h, CONSENSUS)
    why = {p["name"]: p["why"] for p in result(h, code)["groups"][0]["per_person"]}
    assert why["A"].startswith("You liked Shawarma Station.") and "ordered here before" in why["A"]  # the host has history
    assert "ordered here before" not in why["B"]  # guests have none
    assert why["D"].startswith("You skipped Shawarma Station")  # honest about the person who wanted pizza


def test_scores_and_trace_are_present(h):
    code, _ = play(h, CONSENSUS)
    res = result(h, code)
    assert res["scores"] and {"restaurant_id", "restaurant_name", "group_score", "per_person"} <= set(res["scores"][0])
    assert [s["tool"] for s in res["agent_trace"]] == ["cache:food_get_restaurant_menu"]
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


def test_a_restaurant_with_nothing_on_the_menu_is_skipped(h, monkeypatch):
    install(monkeypatch, CATALOG, empty={30101, 30103})
    code, _ = play(h, {n: {"Shawarma Station", "Pizza Piazza", "Sakura Sushi Lab"} for n in "AB"})
    res = result(h, code)
    assert res["status"] == "ready" and res["groups"][0]["restaurant"]["name"] == "Sakura Sushi Lab"
    assert any("nothing to order" in s["output_summary"] for s in res["agent_trace"] if s["failed"])


def test_transient_lookup_errors_are_retried(h, monkeypatch):
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


def test_dine_out_works_the_same_way(h):
    code, host = h.room(mode="dineout", host="A")
    b = h.join(code, "B")
    h.start_swiping(code, host, "lunch")
    for pid in (host, b):
        h.swipe_all(code, pid, lambda c: True)
    for pid in (host, b):
        h.swipe_all(code, pid, lambda c: c["title"] == "Shawarma Station")
    res = result(h, code)
    assert res["status"] == "ready" and res["basket"] == [] and res["restaurant"]["name"] == "Shawarma Station"
    assert len(res["per_person"]) == 2


def test_split_gives_each_camp_its_own_restaurant(h):
    code, p = play(h, {"A": {"Shawarma Station"}, "B": {"Shawarma Station"}, "C": {"Pizza Piazza"}, "D": {"Pizza Piazza"}})
    for n in "ABC":
        h.c.post(f"/rooms/{code}/dispute/vote", json={"participant_id": p[n], "method": "split"})
    h.c.post(f"/rooms/{code}/dispute/confirm", json={"participant_id": p["A"]})
    res = result(h, code)
    assert res["resolution"]["type"] == "split" and len(res["groups"]) == 2 and res["restaurant"] is None
    by_name = {g["restaurant"]["name"]: g for g in res["groups"]}
    assert set(by_name["Shawarma Station"]["participant_ids"]) == {p["A"], p["B"]}
    assert set(by_name["Pizza Piazza"]["participant_ids"]) == {p["C"], p["D"]}
    assert [g["group_id"] for g in res["groups"]] == ["g1", "g2"]
    assert all(g["basket"] == [] for g in res["groups"])
    assert "chose Shawarma Station" in by_name["Shawarma Station"]["reasoning"]
    assert {s["group_id"] for s in res["agent_trace"]} == {"g1", "g2"}


def test_the_planner_never_uses_a_mutating_tool():
    src = Path(planner.__file__).read_text(encoding="utf-8")
    assert not re.search(r"cart_|checkout|create_order|save_new_address|allow_mutating", src)
