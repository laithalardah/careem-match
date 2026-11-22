"""Restaurant catalog: built live from the Careem MCP (read-only lookups) and cached to
fallback_catalog.json. FALLBACK=1 (or any MCP failure) serves the cached file.

    python catalog.py --refresh     # re-fetch from the MCP and rewrite fallback_catalog.json
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path

import config

log = logging.getLogger("catalog")
DEFAULT_CATALOG_PATH = Path(__file__).parent / "fallback_catalog.json"


def cache_path() -> Path:
    """The cached catalog file. CATALOG_PATH lets tests use a frozen, smaller catalog."""
    return Path(os.getenv("CATALOG_PATH") or DEFAULT_CATALOG_PATH)


# Amman, Jordan. (Sandbox data is Dubai/AED and is selected by restaurant id.)
LOCATION = {"latitude": 31.9539, "longitude": 35.9106}
# Demo-only promotions (the sandbox has none): percent off by restaurant id (every restaurant has one).
DEMO_DISCOUNTS = (69, 25, 75, 40, 60, 50, 35, 45)

DISCOVERY_QUERIES = ["shawarma", "burger", "pizza", "sushi", "breakfast", "bowl", "syrniki", "dessert",
                     "gelato", "mandi", "noodles", "foul", "slice", "salad"]

# Cuisine name from the MCP -> the category card shown to people.
CATEGORY_BY_CUISINE = {
    "Arabic": "Shawarma", "Shawarma": "Shawarma", "Lebanese": "Shawarma",
    "Japanese": "Sushi", "Sushi": "Sushi",
    "Italian": "Pizza", "Pizza": "Pizza",
    "Burgers": "Burger", "Burger": "Burger", "American": "Burger",
    "Breakfast": "Breakfast", "Eastern European": "Breakfast", "Cafe": "Breakfast",
    "Healthy": "Healthy", "Salads": "Healthy",
    "Dessert": "Dessert", "Desserts": "Dessert", "Bakery": "Dessert", "Sweets": "Dessert", "Gelato": "Dessert",
    "Asian": "Asian", "Chinese": "Asian", "Noodles": "Asian", "Thai": "Asian",
    "Mandi": "Shawarma",
}
MEAL_CATEGORIES = {
    "breakfast": {"Breakfast", "Healthy"},
    "lunch": {"Shawarma", "Healthy", "Pizza", "Sushi", "Burger", "Asian"},
    "dinner": {"Shawarma", "Pizza", "Sushi", "Healthy", "Burger", "Asian"},
    "dessert": {"Dessert"},
}


@dataclass
class Option:
    id: int
    group_id: int
    catalog_option_id: str
    name: str
    price: float


@dataclass
class OptionGroup:
    id: int
    name: str
    required: bool
    min: int
    max: int
    multi: bool
    options: list[Option] = field(default_factory=list)


@dataclass
class Dish:
    id: str
    name: str
    description: str
    price: float
    image_url: str | None
    active: bool
    option_groups: list[OptionGroup] = field(default_factory=list)

    @property
    def requires_options(self) -> bool:
        return any(g.required for g in self.option_groups)


@dataclass
class Restaurant:
    id: int
    name: str
    image_url: str | None
    cuisines: list[str]
    category: str
    rating: float | None
    eta_minutes: int | None
    link: str
    currency: str
    available: bool
    dishes: list[Dish] = field(default_factory=list)

    @property
    def description(self) -> str:
        """One factual sentence built only from catalog data."""
        names = [d.name for d in self.dishes if d.active][:3]
        cuisine = " and ".join(self.cuisines[:2]) if self.cuisines else "Food"
        if not names:
            return f"{cuisine}."
        if len(names) == 1:
            dishes = names[0]
        else:
            dishes = ", ".join(names[:-1]) + " and " + names[-1]
        return f"{cuisine}. Serves {dishes}."

    @property
    def top_dishes(self) -> list[str]:
        return [d.name for d in self.dishes if d.active][:3]


def _category_of(cuisines: list[str]) -> str:
    for c in cuisines:
        if c in CATEGORY_BY_CUISINE:
            return CATEGORY_BY_CUISINE[c]
    return cuisines[0] if cuisines else "Food"


def parse_menu(rest: dict) -> Restaurant:
    """Turn the restaurant object of food_get_restaurant_menu into a Restaurant."""
    cuisines = [c["name"] for c in rest.get("cuisines", [])]
    dishes: list[Dish] = []
    for g in rest.get("menu", {}).get("groups", []):
        for it in g.get("items", []):
            groups = []
            for og in it.get("groups", []):
                opts = [
                    Option(
                        id=o["id"], group_id=og["id"], catalog_option_id=f"{og['id']}::{o['id']}",
                        name=o["item"], price=float(o["price"]["total"]),
                    )
                    for o in og.get("options", []) if o.get("is_active", True)
                ]
                groups.append(OptionGroup(
                    id=og["id"], name=og["name"], required=og.get("min", 0) > 0,
                    min=og.get("min", 0), max=og.get("max", 1), multi=bool(og.get("multi_select")), options=opts,
                ))
            dishes.append(Dish(
                id=str(it["id"]), name=it["item"], description=it.get("description", ""),
                price=float(it["price"]["total"]), image_url=it.get("image_url"),
                active=bool(it.get("active", True)), option_groups=groups,
            ))
    return Restaurant(
        id=int(rest["id"]), name=rest["name"]["value"], image_url=rest.get("image_url"),
        cuisines=cuisines, category=_category_of(cuisines),
        rating=(rest.get("rating") or {}).get("average"),
        eta_minutes=(rest.get("delivery") or {}).get("average"),
        link=rest.get("link") or f"careemfood://restaurants/{rest['id']}",
        currency=(rest.get("currency") or {}).get("code", ""),
        available=bool((rest.get("availability_details") or {}).get("is_available", True)),
        dishes=dishes,
    )


def _from_dict(d: dict) -> Restaurant:
    dishes = [
        Dish(**{**x, "option_groups": [
            OptionGroup(**{**g, "options": [Option(**o) for o in g["options"]]}) for g in x["option_groups"]
        ]})
        for x in d["dishes"]
    ]
    return Restaurant(**{**d, "dishes": dishes})


class Catalog:
    def __init__(self, restaurants: list[Restaurant], source: str):
        self.restaurants = restaurants
        self.source = source  # "mcp" or "cache"

    def by_id(self, rid: int) -> Restaurant | None:
        return next((r for r in self.restaurants if r.id == rid), None)

    def candidates(self, meal: str | None) -> list[Restaurant]:
        allowed = MEAL_CATEGORIES.get(meal) if meal else None
        return [r for r in self.restaurants if r.available and (allowed is None or r.category in allowed)]

    # ── Cards ────────────────────────────────────────────────────────────────
    def category_cards(self, meal: str | None) -> list[dict]:
        by_cat: dict[str, list[Restaurant]] = {}
        for r in self.candidates(meal):
            by_cat.setdefault(r.category, []).append(r)
        cards = []
        for title, rs in sorted(by_cat.items(), key=lambda kv: (-len(kv[1]), kv[0])):
            n = len(rs)
            cards.append({
                "id": title.lower(), "level": "category", "title": title,
                "subtitle": f"{n} restaurant{'s' if n != 1 else ''} nearby",
                "image_url": next((r.image_url for r in rs if r.image_url), None),
            })
        return cards

    def restaurant_cards(self, categories: set[str], meal: str | None, limit: int = 8) -> list[dict]:
        rs = [r for r in self.candidates(meal) if r.category in categories]
        rs.sort(key=lambda r: (-(r.rating or 0), r.name))
        return [self.restaurant_card(r) for r in rs[:limit]]

    @staticmethod
    def restaurant_card(r: Restaurant) -> dict:
        # The sandbox has no promotions, so the demo gives each restaurant a stable discount (or none) and Plus flag.
        rid = int(r.id) if str(r.id).isdigit() else sum(map(ord, str(r.id)))
        return {
            "id": str(r.id), "level": "restaurant", "title": r.name, "description": r.description,
            "cuisine": r.category, "rating": r.rating, "eta_minutes": r.eta_minutes,
            "image_url": r.image_url, "top_dishes": r.top_dishes,
            "discount_pct": DEMO_DISCOUNTS[rid % len(DEMO_DISCOUNTS)], "careem_plus": rid % 3 != 0,
        }


async def fetch_live() -> list[Restaurant]:
    """Read-only MCP lookups: discover restaurants, then fetch each menu."""
    from mcp_client import Careem

    async with Careem() as c:
        ids: list[int] = []
        for q in DISCOVERY_QUERIES:
            r = await c.call("food_merchant_search", {"query": q, **LOCATION})
            for rest in (r.structured_content or {}).get("restaurants", []):
                if rest["id"] not in ids:
                    ids.append(rest["id"])
        out = []
        for rid in ids:
            r = await c.call("food_get_restaurant_menu", {"restaurant_id": rid, **LOCATION})
            rest = (r.structured_content or {}).get("restaurant")
            if rest:
                out.append(parse_menu(rest))
        return out


def load_cache() -> list[Restaurant]:
    return [_from_dict(d) for d in json.loads(cache_path().read_text(encoding="utf-8"))["restaurants"]]


def save_cache(restaurants: list[Restaurant]) -> None:
    cache_path().write_text(
        json.dumps({"restaurants": [asdict(r) for r in restaurants]}, indent=1, ensure_ascii=False), encoding="utf-8"
    )


_catalog: Catalog | None = None


async def get_catalog(force: bool = False) -> Catalog:
    """Cached for the life of the process. Live MCP unless FALLBACK=1; any MCP failure uses the cache."""
    global _catalog
    if _catalog is not None and not force:
        return _catalog
    if config.fallback_mode():
        _catalog = Catalog(load_cache(), "cache")
        return _catalog
    try:
        rs = await asyncio.wait_for(fetch_live(), timeout=20)
        if not rs:
            raise RuntimeError("MCP returned no restaurants")
        _catalog = Catalog(rs, "mcp")
    except Exception as e:  # noqa: BLE001
        log.warning("MCP catalog failed (%s: %s); using cached catalog", type(e).__name__, e)
        _catalog = Catalog(load_cache(), "cache")
    return _catalog


def reset_catalog() -> None:
    global _catalog
    _catalog = None


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    if "--refresh" in sys.argv:
        rs = asyncio.run(fetch_live())
        save_cache(rs)
        print(f"{len(rs)} restaurants cached -> {cache_path().name}")
        for r in rs:
            print(f"  {r.id} {r.name:<24} {r.category:<10} {r.rating} eta={r.eta_minutes} dishes={len(r.dishes)} open={r.available}")
    else:
        print("usage: python catalog.py --refresh")
