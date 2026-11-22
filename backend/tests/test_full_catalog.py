"""The grown sandbox (13 restaurants): every meal has something, options resolve, flows work."""
import catalog
import pytest
from test_dispute import wait_for


@pytest.fixture()
def full(monkeypatch):
    monkeypatch.setenv("CATALOG_PATH", str(catalog.DEFAULT_CATALOG_PATH))
    catalog.reset_catalog()
    yield catalog.Catalog(catalog.load_cache(), "cache")
    catalog.reset_catalog()


def titles(cat, meal):
    return {c["title"]: c["subtitle"] for c in cat.category_cards(meal)}


def test_every_meal_has_something(full):
    assert len(full.restaurants) == 13
    assert titles(full, "breakfast") == {"Breakfast": "2 restaurants nearby", "Healthy": "2 restaurants nearby"}
    assert titles(full, "dessert") == {"Dessert": "2 restaurants nearby"}  # used to be an empty meal
    lunch = titles(full, "lunch")
    assert set(lunch) == {"Shawarma", "Pizza", "Healthy", "Burger", "Sushi", "Asian"}
    assert lunch["Shawarma"] == "2 restaurants nearby"
    assert "Dessert" not in lunch and "Breakfast" not in lunch


def test_new_cuisines_are_categorised(full):
    cat = {r.name: r.category for r in full.restaurants}
    assert cat["Mandi Palace"] == "Shawarma" and cat["Gelato Corner"] == "Dessert" and cat["Wok Express"] == "Asian"
    assert cat["Sunrise Foul & Falafel"] == "Breakfast"  # Breakfast comes before Arabic in its cuisines


def test_mansaf_and_options_are_in_the_menus(full):
    mandi = full.by_id(30111)
    assert "Lamb Mansaf" in [d.name for d in mandi.dishes]
    mandi_dish = next(d for d in mandi.dishes if d.name == "Chicken Mandi")
    assert mandi_dish.requires_options and [o.name for o in mandi_dish.option_groups[0].options] == ["Plain rice", "Saffron rice"]
    burger = next(d for d in full.by_id(30106).dishes if d.name == "Classic Smash Burger")
    assert [g.required for g in burger.option_groups] == [True, False]


def test_dessert_flow_works_end_to_end(full, h):
    code, host = h.room(host="A")
    b = h.join(code, "B")
    h.start_swiping(code, host, "dessert")
    cards = h.cards(code, host)["cards"]
    assert [c["title"] for c in cards] == ["Dessert"]
    for pid in (host, b):
        h.swipe_all(code, pid, lambda c: True)
    deck = {c["title"] for c in h.cards(code, host)["cards"]}
    assert deck == {"Sweet Tooth Bakery", "Gelato Corner"}
    for pid in (host, b):
        h.swipe_all(code, pid, lambda c: c["title"] == "Gelato Corner")
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    res = h.c.get(f"/rooms/{code}/result").json()
    assert res["status"] == "ready" and res["restaurant"]["name"] == "Gelato Corner"
    assert res["basket"] == [] and res["restaurant"]["link"] == "careemfood://restaurants/30108"


def test_a_burger_lunch_ends_at_the_burger_place(full, h):
    code, host = h.room(host="A")
    b = h.join(code, "B")
    h.start_swiping(code, host, "lunch")
    for pid in (host, b):
        h.swipe_all(code, pid, lambda c: True)
    for pid in (host, b):
        h.swipe_all(code, pid, lambda c: c["title"] == "Smash Burger House")
    assert wait_for(lambda: h.state(code)["stage"] == "result")
    res = h.c.get(f"/rooms/{code}/result").json()
    assert res["status"] == "ready" and res["restaurant"]["name"] == "Smash Burger House"
    assert res["restaurant"]["link"] == "careemfood://restaurants/30106"
