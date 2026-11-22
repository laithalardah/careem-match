"""Room state machine: join, host-only rules, stage guards, level advance."""


def test_health_reports_demo(client):
    assert client.get("/health").json() == {"status": "ok", "demo": True}


def test_create_and_join(h):
    code, host = h.room()
    assert len(code) == 6
    guest = h.join(code, "Lina")
    s = h.state(code, host)
    assert s["stage"] == "lobby" and s["host_id"] == host
    assert [p["name"] for p in s["participants"]] == ["Host", "Lina"]
    assert s["participants"][0]["is_host"] is True and s["participants"][1]["is_host"] is False
    assert s["join_url"].endswith(f"/#/join/{code}")
    assert guest != host


def test_duplicate_names_are_made_distinct(h):
    code, _ = h.room()
    h.join(code, "Omar")
    h.join(code, "omar")
    names = [p["name"] for p in h.state(code)["participants"]]
    assert len(set(n.lower() for n in names)) == 3


def test_version_bumps_on_every_change(h):
    code, host = h.room()
    v0 = h.state(code)["version"]
    h.join(code, "Sara")
    assert h.state(code)["version"] > v0


def test_validation_errors(h, client):
    code, host = h.room()
    assert client.post(f"/rooms/{code}/join", json={"name": "  "}).status_code == 422
    assert client.post(f"/rooms/{code}/join", json={"name": "x" * 40}).status_code == 422
    assert client.post("/rooms", json={"mode": "pizza", "host_name": "A"}).status_code == 422
    assert client.get("/rooms/NOPE12").status_code == 404


def test_host_only_and_stage_guards(h, client):
    code, host = h.room()
    guest = h.join(code, "Lina")
    # guest cannot move the room on
    assert client.post(f"/rooms/{code}/next", json={"participant_id": guest}).status_code == 403
    # settings before lobby is over -> 409
    assert client.put(f"/rooms/{code}/settings", json={"participant_id": host, "meal": "lunch"}).status_code == 409
    assert client.post(f"/rooms/{code}/next", json={"participant_id": host}).status_code == 200
    # joining after the lobby is closed -> 409
    assert client.post(f"/rooms/{code}/join", json={"name": "Late"}).status_code == 409
    # guest cannot pick the meal
    assert client.put(f"/rooms/{code}/settings", json={"participant_id": guest, "meal": "lunch"}).status_code == 403
    # bad meal
    assert client.put(f"/rooms/{code}/settings", json={"participant_id": host, "meal": "brunch"}).status_code == 422
    # a guest cannot start the swiping
    assert client.post(f"/rooms/{code}/start", json={"participant_id": guest}).status_code == 403


def test_next_needs_two_people(h, client):
    code, host = h.room()
    assert client.post(f"/rooms/{code}/next", json={"participant_id": host}).status_code == 409


def test_unknown_participant_is_rejected(h, client):
    code, host = h.room()
    assert client.get(f"/rooms/{code}", params={"participant_id": "p_nope"}).status_code == 403


def test_empty_meal_is_a_readable_409(h, client):
    code, host = h.room()
    h.join(code, "Lina")
    client.post(f"/rooms/{code}/next", json={"participant_id": host})
    client.put(f"/rooms/{code}/settings", json={"participant_id": host, "meal": "dessert"})
    r = client.post(f"/rooms/{code}/start", json={"participant_id": host})
    assert r.status_code == 409 and "dessert" in r.json()["detail"]


def test_categories_then_restaurants(h, client):
    code, host = h.room()
    guest = h.join(code, "Lina")
    h.start_swiping(code, host, "lunch")
    data = h.cards(code, host)
    assert data["level"] == "category"
    titles = {c["title"] for c in data["cards"]}
    assert {"Shawarma", "Pizza", "Sushi", "Healthy"} <= titles
    assert "Breakfast" not in titles  # not a lunch category
    c0 = data["cards"][0]
    assert set(c0) == {"id", "level", "title", "subtitle", "image_url"}

    # host finishes; the level does not advance until the guest finishes too
    h.swipe_all(code, host, lambda c: c["title"] in ("Shawarma", "Pizza"))
    s = h.state(code, host)
    assert s["level"] == "category"
    assert [p["progress"]["done"] for p in s["participants"]] == [True, False]
    h.swipe_all(code, guest, lambda c: c["title"] == "Pizza")

    s = h.state(code, host)
    assert s["level"] == "restaurant"
    deck = h.cards(code, guest)
    assert deck["level"] == "restaurant"
    names = {c["title"] for c in deck["cards"]}
    assert names == {"Shawarma Station", "Pizza Piazza"}  # only liked categories
    card = next(c for c in deck["cards"] if c["title"] == "Pizza Piazza")
    assert set(card) == {"id", "level", "title", "description", "cuisine", "rating", "eta_minutes", "image_url", "top_dishes"}
    assert "Margherita Pizza" in card["top_dishes"] and card["description"].startswith("Italian")


def test_swipe_validation(h, client):
    code, host = h.room()
    h.join(code, "Lina")
    h.start_swiping(code, host)
    card = h.cards(code, host)["cards"][0]
    body = {"participant_id": host, "level": "category", "card_id": card["id"], "liked": True}
    assert client.post(f"/rooms/{code}/swipe", json={**body, "level": "restaurant"}).status_code == 409
    assert client.post(f"/rooms/{code}/swipe", json={**body, "card_id": "nope"}).status_code == 422
    assert client.post(f"/rooms/{code}/swipe", json={**body, "participant_id": "p_x"}).status_code == 403
    r = client.post(f"/rooms/{code}/swipe", json=body)
    assert r.status_code == 200 and r.json()["ok"] is True
    # swiping the same card twice does not double count
    client.post(f"/rooms/{code}/swipe", json=body)
    me = next(p for p in h.state(code)["participants"] if p["id"] == host)
    assert me["progress"]["swiped"] == 1


def test_nobody_likes_anything_is_no_match(h, client):
    code, host = h.room()
    guest = h.join(code, "Lina")
    h.start_swiping(code, host)
    h.swipe_all(code, host, lambda c: False)
    h.swipe_all(code, guest, lambda c: False)
    assert h.state(code)["stage"] == "result"
    assert client.get(f"/rooms/{code}/result").json()["status"] == "no_match"


def test_finishing_restaurant_level_moves_to_matching(h, client):
    code, host = h.room()
    guest = h.join(code, "Lina")
    h.start_swiping(code, host)
    for pid in (host, guest):
        h.swipe_all(code, pid, lambda c: True)
    for pid in (host, guest):
        h.swipe_all(code, pid, lambda c: True)
    assert h.state(code)["stage"] in ("matching", "result", "dispute")
