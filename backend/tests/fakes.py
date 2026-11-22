"""Test doubles: a gateway that can fail on demand, and a scripted Bedrock."""
import json
from dataclasses import replace

import planner
from planner import LookupFailed, cheapest_required_options


class FakeGateway:
    """Read-only gateway with switchable failures. Has NO cart methods on purpose."""

    cached = False

    def __init__(self, catalog, *, close_first=False, fail=None, hollow=False):
        self.catalog = catalog
        self.close_first, self.closed = close_first, None
        self.fail = dict(fail or {})  # restaurant id -> failures left (-1 = always)
        self.hollow = hollow  # required option groups with nothing to choose from
        self.calls = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
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
        if self.hollow:
            dishes = [replace(d, option_groups=[replace(g, options=[]) for g in d.option_groups]) for d in r.dishes]
            return replace(r, dishes=dishes)
        return r

    async def options(self, rid, item_ids):
        self.calls.append(("options", rid))
        r = await self.menu(rid)
        return {d.id: d.option_groups for d in r.dishes if d.id in item_ids}


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
    """A fake model. mode: good | outsider | missing_person | missing_option | always_bad | loop | raises"""

    def __init__(self, catalog, mode="good", exc=None):
        self.catalog, self.mode, self.exc = catalog, mode, exc
        self.calls = 0
        self.task = None

    def _plan(self, rid, *, drop_last=False, skip_options=False):
        rest = self.catalog.by_id(rid)
        people = [p["participant_id"] for p in self.task["people"]]
        if drop_last:
            people = people[:-1]
        lines = []
        for i, pid in enumerate(people):
            dish = [d for d in rest.dishes if d.active][i % len([d for d in rest.dishes if d.active])]
            opts = [] if skip_options else [o.catalog_option_id for o in cheapest_required_options(dish, dish.option_groups)]
            lines.append({"participant_id": pid, "item_id": dish.id, "option_ids": opts})
        return {"restaurant_id": rid, "lines": lines, "reasoning": f"{rest.name} suits everyone.",
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
        if self.mode == "outsider":
            if n == 1:
                return _resp([tool("get_restaurant_menu", {"restaurant_id": 30105}, n)])  # not on the shortlist
            if n == 2:
                return _resp([tool("get_restaurant_menu", {"restaurant_id": first}, n)])
            return _resp([tool("submit_plan", self._plan(first), n)])
        if n == 1:
            return _resp([tool("get_restaurant_menu", {"restaurant_id": first}, n)])
        if self.mode == "good":
            return _resp([tool("submit_plan", self._plan(first), n)])
        if self.mode == "missing_person":
            return _resp([tool("submit_plan", self._plan(first, drop_last=True), n)])
        if self.mode == "missing_option":
            return _resp([tool("submit_plan", self._plan(first, skip_options=True), n)])
        if self.mode == "bad_then_good":
            return _resp([tool("submit_plan", self._plan(first, drop_last=True) if n == 2 else self._plan(first), n)])
        raise AssertionError(self.mode)
