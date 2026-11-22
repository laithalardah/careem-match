"""Test doubles: a gateway that can fail on demand, and a scripted Bedrock."""
import json
from dataclasses import replace

import planner
from planner import LookupFailed


class FakeGateway:
    """Read-only gateway with switchable failures. Has NO cart methods on purpose."""

    cached = False

    def __init__(self, catalog, *, close_first=False, fail=None, empty=(), wrap_exit=False):
        self.catalog = catalog
        self.wrap_exit = wrap_exit  # mimic the MCP session turning escaping exceptions into an ExceptionGroup
        self.close_first, self.closed = close_first, None
        self.fail = dict(fail or {})  # restaurant id -> failures left (-1 = always)
        self.empty = set(empty)  # restaurant ids that are open but have no active dishes
        self.calls = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        if self.wrap_exit and exc[1] is not None:
            raise ExceptionGroup("unhandled errors in a TaskGroup", [exc[1]])
        return None

    async def menu(self, rid):
        self.calls.append(("menu", rid))
        left = self.fail.get(rid, 0)
        if left:
            if left > 0:
                self.fail[rid] = left - 1
            raise LookupFailed("upstream unavailable")
        r = self.catalog.by_id(rid)
        if self.close_first and self.closed is None:
            self.closed = rid
        if rid == self.closed:
            return replace(r, available=False)
        if rid in self.empty:
            return replace(r, dishes=[replace(d, active=False) for d in r.dishes])
        return r


def install(monkeypatch, catalog, **kw):
    gws = []

    def factory(room):
        gw = FakeGateway(catalog, **kw)
        gws.append(gw)
        return gw

    monkeypatch.setattr(planner, "GATEWAY_FACTORY", factory)
    return gws


def _resp(content, tokens=100):
    return {"output": {"message": {"role": "assistant", "content": content}}, "usage": {"inputTokens": tokens, "outputTokens": 20}}


def tool(name, args, n=1):
    return {"toolUse": {"toolUseId": f"t{n}", "name": name, "input": args}}


class ScriptedBedrock:
    """A fake model. mode: good | outsider | submit_outsider | bad_then_good | always_outsider | first_even_if_closed | loop | raises"""

    def __init__(self, catalog, mode="good", exc=None):
        self.catalog, self.mode, self.exc = catalog, mode, exc
        self.calls = 0
        self.task = None

    def _plan(self, rid):
        rest = self.catalog.by_id(rid)
        people = [p["participant_id"] for p in self.task["people"]]
        return {"restaurant_id": rid, "reasoning": f"{rest.name} suits everyone.",
                "per_person": [{"participant_id": p, "why": "Fits your votes."} for p in people]}

    def __call__(self, messages, **kw):
        self.calls += 1
        if self.mode == "raises":
            raise self.exc
        if self.task is None:
            self.task = json.loads(messages[0]["content"][0]["text"])
        first = self.task["shortlist"][0]["restaurant_id"]
        n = self.calls
        if self.mode == "loop":
            return _resp([tool("get_restaurant_menu", {"restaurant_id": first}, n)])
        if self.mode == "outsider":  # looks at a restaurant that is not on the shortlist first
            if n == 1:
                return _resp([tool("get_restaurant_menu", {"restaurant_id": 30105}, n)])
            if n == 2:
                return _resp([tool("get_restaurant_menu", {"restaurant_id": first}, n)])
            return _resp([tool("submit_plan", self._plan(first), n)])
        if n == 1:
            return _resp([tool("get_restaurant_menu", {"restaurant_id": first}, n)])
        if self.mode in ("good", "first_even_if_closed"):
            return _resp([tool("submit_plan", self._plan(first), n)])
        if self.mode == "always_outsider":
            return _resp([tool("submit_plan", self._plan(30105), n)])
        if self.mode == "bad_then_good":
            return _resp([tool("submit_plan", self._plan(30105) if n == 2 else self._plan(first), n)])
        raise AssertionError(self.mode)
