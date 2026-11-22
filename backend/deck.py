"""Build the swipe deck from real Careem Food dishes (read-only MCP lookups) and cache it.

    python deck.py          # fetch via MCP, write fallback.json
Other code calls load_deck() (reads fallback.json) so the app never depends on a live fetch.
"""
import asyncio
import json
import os
import sys
from pathlib import Path

from mcp_client import Careem

FALLBACK_PATH = Path(__file__).parent / "fallback.json"
MAX_DECK = 12
# Free-text queries used to discover restaurants (read-only searches).
DISCOVERY_QUERIES = ["syrniki", "sushi", "pizza", "shawarma", "bowl", "breakfast"]
# Amman, Jordan. (Sandbox data is Dubai/AED; selection is by restaurant id.)
LOCATION = {"latitude": 31.9539, "longitude": 35.9106}


async def build_deck() -> dict:
    async with Careem() as c:
        ids: list[int] = []
        for q in DISCOVERY_QUERIES:
            r = await c.call("food_merchant_search", {"query": q, **LOCATION})
            for rest in (r.structured_content or {}).get("restaurants", []):
                if rest["id"] not in ids:
                    ids.append(rest["id"])

        restaurants, dishes = {}, []
        for rid in ids:
            r = await c.call("food_get_restaurant_menu", {"restaurant_id": rid, **LOCATION})
            rest = (r.structured_content or {}).get("restaurant")
            if not rest or not rest.get("availability_details", {}).get("is_available", True):
                continue
            cuisine = rest["cuisines"][0]["name"] if rest.get("cuisines") else ""
            restaurants[str(rid)] = {
                "id": rid,
                "name": rest["name"]["value"],
                "image_url": rest.get("image_url"),
                "cuisine": cuisine,
                "rating": (rest.get("rating") or {}).get("average"),
                "currency": rest["currency"]["code"],
            }
            for g in rest["menu"]["groups"]:
                for it in g["items"]:
                    if not it.get("active", True):
                        continue
                    dishes.append({
                        "id": str(it["id"]),
                        "name": it["item"],
                        "image_url": it.get("image_url"),
                        "cuisine": cuisine,
                        "restaurant_id": rid,
                        "price": it["price"]["total"],
                        "requires_options": any(og["min"] > 0 for og in it.get("groups", [])),
                    })
    return {"source": os.getenv("MCP_URL", "sandbox"), "restaurants": restaurants, "dishes": dishes[:MAX_DECK]}


def load_deck() -> dict:
    return json.loads(FALLBACK_PATH.read_text(encoding="utf-8"))


def public_dishes(deck: dict) -> list[dict]:
    """What POST /session/start returns: only the fields the app needs."""
    return [{k: d[k] for k in ("id", "name", "image_url", "cuisine")} for d in deck["dishes"]]


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    deck = asyncio.run(build_deck())
    FALLBACK_PATH.write_text(json.dumps(deck, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"{len(deck['dishes'])} dishes from {len(deck['restaurants'])} restaurants -> {FALLBACK_PATH.name}")
    for d in deck["dishes"]:
        r = deck["restaurants"][str(d["restaurant_id"])]
        print(f"  {d['id']}  {d['name']:<32} {d['price']:>5} {r['currency']}  [{r['name']}]  options={d['requires_options']}")
