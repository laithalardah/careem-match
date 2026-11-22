"""Drive the whole flow against a running backend: room -> demo friends -> swipes -> (dispute) -> result.

    # terminal 1 (sandbox MCP must be running unless FALLBACK=1)
    DEMO=1 uvicorn main:app --host 0.0.0.0 --port 8000
    # terminal 2
    python scripts/demo_room.py --scenario consensus
    python scripts/demo_room.py --scenario wheel
    python scripts/demo_room.py --scenario split
    python scripts/demo_room.py --scenario split --order     # also builds the basket (sandbox only, NEVER checks out)

You play the host; demo friends (bots) play everyone else. Needs the backend started with DEMO=1.
"""
from __future__ import annotations

import argparse
import sys
import time

import httpx

sys.stdout.reconfigure(encoding="utf-8")


def die(msg: str):
    print(f"\nERROR: {msg}")
    sys.exit(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://127.0.0.1:8000")
    ap.add_argument("--scenario", choices=["consensus", "wheel", "split"], default="consensus")
    ap.add_argument("--friends", type=int, default=3)
    ap.add_argument("--meal", default="lunch")
    ap.add_argument("--order", action="store_true", help="also create the basket (host approval). Never checks out.")
    a = ap.parse_args()
    http = httpx.Client(base_url=a.base, timeout=60)

    def call(method, path, **kw):
        r = http.request(method, path, **kw)
        if r.status_code >= 400:
            die(f"{method} {path} -> {r.status_code} {r.text}")
        return r.json()

    try:
        health = call("GET", "/health")
    except httpx.ConnectError:
        die(f"No backend at {a.base}. Start it:  DEMO=1 uvicorn main:app --port 8000")
    if not health.get("demo"):
        die("Backend started without DEMO=1 (demo friends are off).")

    dispute_run = a.scenario in ("wheel", "split")
    room = call("POST", "/rooms", json={"mode": "food", "host_name": "Host"})
    code, host = room["room_code"], room["participant_id"]
    print(f"Room {code}  join link: {room['join_url']}")
    call("POST", f"/rooms/{code}/demo-friends", json={"participant_id": host, "count": a.friends, "scenario": "dispute" if dispute_run else "consensus"})
    call("POST", f"/rooms/{code}/next", json={"participant_id": host})
    call("PUT", f"/rooms/{code}/settings", json={"participant_id": host, "meal": a.meal})
    call("POST", f"/rooms/{code}/start", json={"participant_id": host})
    state = call("GET", f"/rooms/{code}")
    print("People:", ", ".join(f"{p['name']}{' (host)' if p['is_host'] else ''}{' [demo]' if p['is_bot'] else ''}" for p in state["participants"]))

    # The host likes every category, then at level 2 sides with the SECOND camp (dispute) or the first (consensus).
    def swipe_level(pick):
        data = call("GET", f"/rooms/{code}/cards", params={"participant_id": host})
        print(f"  level {data['level']}: " + ", ".join(c["title"] for c in data["cards"]))
        for c in data["cards"]:
            call("POST", f"/rooms/{code}/swipe", json={"participant_id": host, "level": data["level"], "card_id": c["id"], "liked": pick(c)})

    swipe_level(lambda c: True)
    # Wait for demo friends to finish the category level (they swipe with small delays).
    deadline = time.time() + 60
    while call("GET", f"/rooms/{code}")["level"] != "restaurant":
        if time.time() > deadline:
            die("Timed out waiting for demo friends on level 1.")
        time.sleep(0.5)
    deck = call("GET", f"/rooms/{code}/cards", params={"participant_id": host})["cards"]
    favourite = deck[1]["title"] if (dispute_run and len(deck) > 1) else deck[0]["title"]
    print(f"  host sides with: {favourite}")
    swipe_level(lambda c: c["title"] == favourite)

    seen, deadline = None, time.time() + 120
    while time.time() < deadline:
        s = call("GET", f"/rooms/{code}")
        if s["stage"] != seen:
            seen = s["stage"]
            print(f"  stage -> {seen}")
        if s["stage"] == "dispute":
            d = s["dispute"]
            if not d["method"]:
                if host not in d["method_votes"]:
                    print("  contenders: " + " vs ".join(f"{c['name']} ({len(c['supporter_ids'])})" for c in d["contenders"]))
                    call("POST", f"/rooms/{code}/dispute/vote", json={"participant_id": host, "method": "wheel" if a.scenario == "wheel" else "split"})
            elif d["method"] == "wheel" and not d["wheel"]["spin_id"]:
                call("POST", f"/rooms/{code}/dispute/spin", json={"participant_id": host})
                w = call("GET", f"/rooms/{code}")["dispute"]["wheel"]
                print(f"  wheel spun: angle {w['final_angle_deg']} deg, winner restaurant {w['winner_restaurant_id']}")
            elif d["method"] == "split" and not d["split"]["confirmed"]:
                print("  groups: " + " | ".join(f"{g['name']}: {len(g['participant_ids'])}" for g in d["split"]["groups"]))
                call("POST", f"/rooms/{code}/dispute/confirm", json={"participant_id": host})
        if s["stage"] in ("result", "ordered"):
            break
        time.sleep(0.4)
    else:
        die("Timed out waiting for the result.")

    res = call("GET", f"/rooms/{code}/result")
    print(f"\nRESULT: {res['status']}  resolution={res['resolution']['type']}")
    for g in res["groups"]:
        print(f"\n[{g['group_id']}] {g['restaurant']['name']}  ({', '.join(p['name'] for p in g['per_person'])})")
        for b in g["basket"]:
            print(f"   {b['name']:<8} {b['dish_name']:<34} {b['price']:>7.2f} {g['currency']}  {b['options']}")
        print(f"   total {g['total_price']:.2f} {g['currency']}  | {g['reasoning']}")
    if res["status"] != "ready":
        print("  ", res["reasoning"])
    print("\nAGENT TRACE")
    for t in res["agent_trace"]:
        print(f"  {t['iteration']:>2}. [{t['group_id']}] {'FAILED ' if t['failed'] else ''}{t['tool']}: {t['output_summary']}")

    if a.order and res["status"] == "ready":
        print("\nORDER (host approval; the basket only, no checkout)")
        o = call("POST", f"/rooms/{code}/order", json={"participant_id": host})
        print(f"  {o['status']}: {o['message']}")
        for g in o["groups"]:
            pb = g.get("price_breakdown") or {}
            print(f"   {g['group_id']}: {g['status']} total={pb.get('total')} {pb.get('currency', '')} link={g['restaurant_link']}")
            print(f"      {g['message']}")


if __name__ == "__main__":
    main()
