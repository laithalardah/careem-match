"""Group order: host approval, no checkout, no double adds, unknown outcomes."""
import re
from pathlib import Path

import order
from test_dispute import play, wait_for

CONSENSUS = {"A": {"Shawarma Station"}, "B": {"Shawarma Station"}, "C": {"Shawarma Station"}, "D": {"Pizza Piazza"}}
SPLIT = {"A": {"Shawarma Station"}, "B": {"Shawarma Station"}, "C": {"Pizza Piazza"}, "D": {"Pizza Piazza"}}


class FakeCart:
    """Records every call. mode: ok | partial | timeout | refused"""

    cached = False

    def __init__(self, mode="ok", log=None):
        self.mode, self.log = mode, log if log is not None else []

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return None

    async def add_items(self, merchant_id, items):
        self.log.append(("add", merchant_id, items))
        if self.mode == "timeout":
            raise order.AddUnknown("TimeoutError")
        if self.mode == "refused":
            return [{"success": False, "error": "merchant closed"} for _ in items]
        if self.mode == "fixed":  # like the sandbox: answers about items we never sent
            return [{"catalog_item_id": "700401", "success": True}, {"catalog_item_id": "700402", "success": True}]
        ids = [i["catalog_item_id"] for i in items]
        if self.mode == "partial" and len([c for c in self.log if c[0] == "add"]) == 1:
            return [{"catalog_item_id": ids[i], "success": i != 1, "error": "out of stock"} for i in range(len(items))]
        return [{"catalog_item_id": ids[i], "success": True, "item_uuid": f"u{i}"} for i in range(len(items))]

    async def price(self, merchant_id):
        self.log.append(("price", merchant_id))
        return {"price": {"breakdown": [
            {"label": {"title": "Subtotal"}, "value": [{"price": 100}]},
            {"label": {"title": "Delivery fee"}, "value": [{"price": 5}]},
            {"label": {"title": "Total"}, "value": [{"price": 105}]}], "price": {"title": "Total", "total": 105}}}


def ready(h, who=CONSENSUS):
    code, pids = play(h, who)
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    return code, pids


def post(h, code, pid):
    return h.c.post(f"/rooms/{code}/order", json={"participant_id": pid})


def test_only_the_host_can_approve_and_only_after_a_result(h, monkeypatch):
    log = []
    monkeypatch.setattr(order, "CART_FACTORY", lambda: FakeCart(log=log))
    code, host = h.room(host="A")
    h.join(code, "B")
    assert post(h, code, host).status_code == 409  # no result yet
    code, pids = ready(h)
    assert post(h, code, pids["B"]).status_code == 403
    assert post(h, code, "p_x").status_code == 403
    assert log == []  # nothing was sent


def test_sandbox_shows_our_estimate_not_its_fixed_price(h, monkeypatch):
    log = []
    monkeypatch.setattr(order, "CART_FACTORY", lambda: FakeCart(log=log))
    code, pids = ready(h)  # MCP_URL is the local sandbox in tests
    g = post(h, code, pids["A"]).json()["groups"][0]
    est = round(sum(b["price"] for b in h.c.get(f"/rooms/{code}/result").json()["groups"][0]["basket"]), 2)
    assert g["price_breakdown"]["total"] == est and "estimate" in g["message"]
    assert not [c for c in log if c[0] == "price"]  # the fixed sandbox price is not even read


def test_host_approval_adds_everyone_once_and_never_checks_out(h, monkeypatch):
    monkeypatch.setenv("MCP_URL", "https://mcp.careemapis.com/mcp")  # real price breakdown path
    log = []
    monkeypatch.setattr(order, "CART_FACTORY", lambda: FakeCart(log=log))
    code, pids = ready(h)
    res = post(h, code, pids["A"])
    assert res.status_code == 200
    body = res.json()
    assert body["status"] == "basket_ready" and h.state(code)["stage"] == "ordered"
    g = body["groups"][0]
    assert g["status"] == "basket_ready" and g["restaurant_link"] and g["price_breakdown"]["total"] == 105
    assert g["price_breakdown"]["lines"][0] == {"label": "Subtotal", "amount": 100}
    adds = [c for c in log if c[0] == "add"]
    assert len(adds) == 1  # ONE cart_add_items call for the whole group
    items = adds[0][2]
    assert len(items) == 4 and {i["comment"] for i in items} == {"for A", "for B", "for C", "for D"}
    assert all(i["count"] == 1 for i in items)
    wrap = [i for i in items if i["catalog_item_id"] == "700101"]
    assert all(i["options"] and {"catalog_option_id", "count"} == set(i["options"][0]) for i in wrap)


def test_a_second_tap_changes_nothing(h, monkeypatch):
    log = []
    monkeypatch.setattr(order, "CART_FACTORY", lambda: FakeCart(log=log))
    code, pids = ready(h)
    first = post(h, code, pids["A"]).json()
    again = post(h, code, pids["A"]).json()
    assert again == first and len([c for c in log if c[0] == "add"]) == 1


def test_split_makes_one_basket_per_restaurant(h, monkeypatch):
    log = []
    monkeypatch.setattr(order, "CART_FACTORY", lambda: FakeCart(log=log))
    code, p = play(h, SPLIT)
    for n in "ABC":
        h.c.post(f"/rooms/{code}/dispute/vote", json={"participant_id": p[n], "method": "split"})
    h.c.post(f"/rooms/{code}/dispute/confirm", json={"participant_id": p["A"]})
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    body = post(h, code, p["A"]).json()
    assert body["status"] == "basket_ready" and len(body["groups"]) == 2
    merchants = {c[1] for c in log if c[0] == "add"}
    assert merchants == {30101, 30103}
    assert all(len(c[2]) == 2 for c in log if c[0] == "add")  # two people per basket


def test_timeout_is_not_retried_and_says_the_outcome_is_unknown(h, monkeypatch):
    log = []
    monkeypatch.setattr(order, "CART_FACTORY", lambda: FakeCart("timeout", log))
    code, pids = ready(h)
    body = post(h, code, pids["A"]).json()
    assert body["status"] == "failed"
    msg = body["groups"][0]["message"]
    assert "could not confirm" in msg and "before trying again" in msg
    assert len([c for c in log if c[0] == "add"]) == 1  # no automatic retry
    assert h.state(code)["stage"] == "result"  # the host can decide


def test_partial_failure_retry_only_adds_what_is_missing(h, monkeypatch):
    log = []
    monkeypatch.setattr(order, "CART_FACTORY", lambda: FakeCart("partial", log))
    code, pids = ready(h)
    first = post(h, code, pids["A"]).json()
    assert first["status"] == "failed" and "out of stock" in first["groups"][0]["message"]
    second = post(h, code, pids["A"]).json()  # host presses again: a new, explicit approval
    assert second["status"] == "basket_ready"
    adds = [c for c in log if c[0] == "add"]
    assert len(adds) == 2 and len(adds[0][2]) == 4 and len(adds[1][2]) == 1  # only the one that failed


def test_sandbox_fixed_answers_are_accepted_with_a_note(h, monkeypatch):
    monkeypatch.setattr(order, "CART_FACTORY", lambda: FakeCart("fixed"))
    code, pids = ready(h)  # MCP_URL is the local sandbox in tests
    body = post(h, code, pids["A"]).json()
    assert body["status"] == "basket_ready"
    assert "could not be verified" in body["groups"][0]["message"]


def test_against_the_real_mcp_unconfirmed_items_are_a_failure(h, monkeypatch):
    monkeypatch.setenv("MCP_URL", "https://mcp.careemapis.com/mcp")
    monkeypatch.setattr(order, "CART_FACTORY", lambda: FakeCart("fixed"))
    code, pids = ready(h)
    body = post(h, code, pids["A"]).json()
    assert body["status"] == "failed" and "did not confirm" in body["groups"][0]["message"]
    assert h.state(code)["stage"] == "result"


def test_confirmations_are_matched_by_item_id_not_position():
    from planner import Plan, PlanLine
    from catalog import Catalog, load_cache

    r = Catalog(load_cache(), "cache").by_id(30101)
    wrap, falafel = r.dishes[0], r.dishes[1]
    plan = Plan(r, [PlanLine("a", wrap), PlanLine("b", falafel)], "", [])
    # answers come back in the opposite order, one failed
    results = [{"catalog_item_id": falafel.id, "success": False, "error": "sold out"}, {"catalog_item_id": wrap.id, "success": True}]
    added, failed, unverified = order.match_results(plan, [0, 1], results)
    assert added == {0} and unverified == set() and failed == [f"{falafel.name} (sold out)"]


def test_refused_call_is_reported(h, monkeypatch):
    monkeypatch.setattr(order, "CART_FACTORY", lambda: FakeCart("refused"))
    code, pids = ready(h)
    body = post(h, code, pids["A"]).json()
    assert body["status"] == "failed" and "merchant closed" in body["groups"][0]["message"]


def test_cached_mode_sends_nothing_and_says_so(h):
    code, pids = ready(h)  # FALLBACK=1 -> SimulatedCart
    body = post(h, code, pids["A"]).json()
    g = body["groups"][0]
    assert body["status"] == "basket_ready" and "nothing was sent" in g["message"].lower()
    assert g["price_breakdown"]["lines"][0]["label"].startswith("Subtotal")


def test_dine_out_just_returns_the_link(h, monkeypatch):
    log = []
    monkeypatch.setattr(order, "CART_FACTORY", lambda: FakeCart(log=log))
    code, host = h.room(mode="dineout", host="A")
    b = h.join(code, "B")
    h.start_swiping(code, host, "lunch")
    for pid in (host, b):
        h.swipe_all(code, pid, lambda c: True)
    for pid in (host, b):
        h.swipe_all(code, pid, lambda c: c["title"] == "Shawarma Station")
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    body = post(h, code, host).json()
    assert body["status"] == "go" and body["groups"][0]["status"] == "go" and body["groups"][0]["restaurant_link"]
    assert log == []


def test_no_checkout_or_order_tool_exists_in_the_code():
    for name in ("order.py", "planner.py", "agent.py", "mcp_client.py"):
        src = Path(__file__).resolve().parent.parent.joinpath(name).read_text(encoding="utf-8")
        calls = re.findall(r'call(?:_tool)?\(\s*["\'](\w+)["\']', src)
        assert not [c for c in calls if "checkout" in c or "create_order" in c], (name, calls)
    assert order.ALLOWED_MUTATIONS == {"cart_add_items"}
