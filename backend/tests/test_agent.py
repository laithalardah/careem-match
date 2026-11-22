"""Bedrock agent loop with a scripted fake model: validation, repair, fallback, caps."""
import re
from pathlib import Path

import agent
import bedrock_client
from catalog import Catalog, load_cache
from fakes import ScriptedBedrock, install
from test_dispute import play, wait_for

CATALOG = Catalog(load_cache(), "cache")
CONSENSUS = {"A": {"Shawarma Station"}, "B": {"Shawarma Station"}, "C": {"Shawarma Station"}, "D": {"Pizza Piazza"}}


def run(h, monkeypatch, model, who=CONSENSUS):
    monkeypatch.setenv("AGENT_MODE", "bedrock")
    monkeypatch.setattr(bedrock_client, "converse", model)
    code, _ = play(h, who)
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    return h.c.get(f"/rooms/{code}/result").json()


def steps(res, tool):
    return [s for s in res["agent_trace"] if s["tool"] == tool]


def test_happy_path_uses_the_models_choice(h, monkeypatch):
    model = ScriptedBedrock(CATALOG, "good")
    res = run(h, monkeypatch, model)
    assert res["status"] == "ready"
    g = res["groups"][0]
    assert g["restaurant"]["name"] == "Shawarma Station"
    assert g["reasoning"] == "Shawarma Station suits everyone." and all(p["why"] == "Fits your votes." for p in g["per_person"])
    assert steps(res, "bedrock_agent") and "accepted" in steps(res, "submit_plan")[-1]["output_summary"]
    assert g["basket"] == [] and model.calls == 2  # look at the restaurant, then submit
    assert not any(s["failed"] for s in res["agent_trace"])


def test_restaurant_outside_the_shortlist_is_refused_when_looking_it_up(h, monkeypatch):
    model = ScriptedBedrock(CATALOG, "outsider")
    res = run(h, monkeypatch, model)
    assert res["status"] == "ready" and model.calls == 3
    assert res["groups"][0]["restaurant"]["id"] != 30105


def test_submitting_an_outsider_is_rejected_then_repaired(h, monkeypatch):
    res = run(h, monkeypatch, ScriptedBedrock(CATALOG, "bad_then_good"))
    rejected = [s for s in steps(res, "submit_plan") if s["failed"]]
    assert len(rejected) == 1 and "not on the shortlist" in rejected[0]["output_summary"]
    assert res["status"] == "ready" and res["groups"][0]["restaurant"]["name"] == "Shawarma Station"
    assert not steps(res, "replan") and not steps(res, "agent")


def test_rejected_twice_falls_back_to_the_planner(h, monkeypatch):
    res = run(h, monkeypatch, ScriptedBedrock(CATALOG, "always_outsider"))
    assert res["status"] == "ready" and res["groups"][0]["restaurant"]["name"] == "Shawarma Station"
    fb = [s for s in steps(res, "agent") if s["failed"]]
    assert fb and "deterministic planner" in fb[0]["output_summary"]


def test_a_closed_restaurant_is_rejected_and_the_planner_moves_on(h, monkeypatch):
    install(monkeypatch, CATALOG, close_first=True)  # the first restaurant looked up is closed
    both = {n: {"Shawarma Station", "Pizza Piazza"} for n in "ABC"}
    res = run(h, monkeypatch, ScriptedBedrock(CATALOG, "first_even_if_closed"), both)
    rejected = [s for s in steps(res, "submit_plan") if s["failed"]]
    assert rejected and "closed" in rejected[0]["output_summary"]
    assert res["status"] == "ready"  # never ends on the closed restaurant


def test_iteration_cap_then_fallback(h, monkeypatch):
    model = ScriptedBedrock(CATALOG, "loop")
    res = run(h, monkeypatch, model)
    assert model.calls == agent.MAX_ITERATIONS
    assert res["status"] == "ready" and steps(res, "agent")


def test_expired_credentials_fall_back_with_a_hint(h, monkeypatch):
    from botocore.exceptions import ClientError

    err = ClientError({"Error": {"Code": "ExpiredTokenException", "Message": "The security token included in the request is expired"}}, "Converse")
    res = run(h, monkeypatch, ScriptedBedrock(CATALOG, "raises", exc=err))
    assert res["status"] == "ready"
    msg = steps(res, "agent")[0]["output_summary"]
    assert "refresh_env.ps1" in msg and "ClientError" in msg


def test_any_bedrock_error_falls_back(h, monkeypatch):
    res = run(h, monkeypatch, ScriptedBedrock(CATALOG, "raises", exc=TimeoutError("read timed out")))
    assert res["status"] == "ready" and "TimeoutError" in steps(res, "agent")[0]["output_summary"]
    assert "refresh_env.ps1" not in steps(res, "agent")[0]["output_summary"]


def test_bedrock_call_has_no_deprecated_temperature(h, monkeypatch):
    seen = {}
    inner = ScriptedBedrock(CATALOG, "good")

    def spy(messages, **kw):
        seen.update(kw)
        return inner(messages, **kw)

    run(h, monkeypatch, spy)
    assert "temperature" not in seen.get("inferenceConfig", {}) and seen["inferenceConfig"]["maxTokens"] > 0


def test_model_only_gets_read_only_tools_and_cannot_order():
    names = {t["toolSpec"]["name"] for t in agent.TOOLS}
    assert names == {"get_restaurant_menu", "submit_plan"}
    src = Path(agent.__file__).read_text(encoding="utf-8")
    assert not re.search(r"cart_|checkout|create_order|save_new_address|allow_mutating", src)
    assert "never order" in agent.SYSTEM.lower()


def test_credentials_are_never_cached(monkeypatch, tmp_path):
    """make_client() re-reads .env on every call."""
    seen = []
    monkeypatch.setattr(bedrock_client.boto3, "client", lambda *a, **kw: seen.append(kw["aws_access_key_id"]) or object())
    env = tmp_path / ".env"
    monkeypatch.setattr(bedrock_client, "ENV_PATH", env)
    env.write_text("AWS_ACCESS_KEY_ID=first\nAWS_SECRET_ACCESS_KEY=s\nAWS_SESSION_TOKEN=t\n")
    bedrock_client.make_client()
    env.write_text("AWS_ACCESS_KEY_ID=second\nAWS_SECRET_ACCESS_KEY=s\nAWS_SESSION_TOKEN=t\n")
    bedrock_client.make_client()
    assert seen == ["first", "second"]
