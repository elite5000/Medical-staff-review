from typing import cast

from fastapi.testclient import TestClient


def _setup_simple_scenario(client: TestClient) -> dict[str, object]:
    building = client.post(
        "/buildings", json={"name": "Hospital", "opening_minutes": 480, "closing_minutes": 720}
    ).json()
    room = client.post(
        "/rooms", json={"name": "Room 1", "building_id": building["id"], "tag_ids": []}
    ).json()
    staff = client.post("/staff", json={"name": "Dr. Alice"}).json()
    return {"building": building, "room": room, "staff": staff}


def test_generate_roster_creates_shifts(client: TestClient) -> None:
    _setup_simple_scenario(client)
    response = client.post("/rosters", json={"start_date": "2026-08-03", "num_days": 1})
    assert response.status_code == 201
    roster = response.json()
    assert roster["start_date"] == "2026-08-03"
    assert roster["end_date"] == "2026-08-03"

    detail = client.get(f"/rosters/{roster['id']}").json()
    assert len(detail["shifts"]) == 1
    assert detail["shifts"][0]["pinned"] is False


def test_list_rosters(client: TestClient) -> None:
    _setup_simple_scenario(client)
    client.post("/rosters", json={"start_date": "2026-08-03", "num_days": 1})
    response = client.get("/rosters")
    assert response.status_code == 200
    assert len(response.json()) == 1


def test_get_missing_roster_404(client: TestClient) -> None:
    assert client.get("/rosters/999").status_code == 404


def test_regenerate_roster_carries_pinned_shifts_forward(client: TestClient) -> None:
    ctx = _setup_simple_scenario(client)
    first = client.post("/rosters", json={"start_date": "2026-08-03", "num_days": 1}).json()
    detail = client.get(f"/rosters/{first['id']}").json()
    shift = detail["shifts"][0]

    pin_response = client.patch(
        f"/rosters/{first['id']}/shifts/{shift['id']}",
        json={"staff_id": cast(dict[str, object], ctx["staff"])["id"]},
    )
    assert pin_response.status_code == 200
    assert pin_response.json()["pinned"] is True

    regenerated = client.post(f"/rosters/{first['id']}/regenerate")
    assert regenerated.status_code == 201
    assert regenerated.json()["generated_from_roster_id"] == first["id"]

    new_detail = client.get(f"/rosters/{regenerated.json()['id']}").json()
    carried = next(
        s
        for s in new_detail["shifts"]
        if s["room_id"] == cast(dict[str, object], ctx["room"])["id"]
    )
    assert carried["staff_id"] == cast(dict[str, object], ctx["staff"])["id"]
    assert carried["pinned"] is True


def test_regenerate_missing_roster_404(client: TestClient) -> None:
    assert client.post("/rosters/999/regenerate").status_code == 404


def test_manual_edit_rejects_ineligible_staff(client: TestClient) -> None:
    tag = client.post("/tags", json={"name": "Emergency Department"}).json()
    role = client.post("/roles", json={"name": "Senior Fellow"}).json()
    client.post(
        "/rules",
        json={
            "name": "ED eligibility",
            "rule_type": "eligibility_restriction",
            "role_id": role["id"],
            "tag_id": tag["id"],
        },
    )
    building = client.post(
        "/buildings", json={"name": "Hospital", "opening_minutes": 480, "closing_minutes": 720}
    ).json()
    room = client.post(
        "/rooms", json={"name": "ED Room", "building_id": building["id"], "tag_ids": [tag["id"]]}
    ).json()
    qualified = client.post("/staff", json={"name": "Dr. Alice", "role_ids": [role["id"]]}).json()
    unqualified = client.post("/staff", json={"name": "Dr. Bob"}).json()

    roster = client.post("/rosters", json={"start_date": "2026-08-03", "num_days": 1}).json()
    detail = client.get(f"/rosters/{roster['id']}").json()
    shift = next(s for s in detail["shifts"] if s["room_id"] == room["id"])
    assert shift["staff_id"] == qualified["id"]

    response = client.patch(
        f"/rosters/{roster['id']}/shifts/{shift['id']}",
        json={"staff_id": unqualified["id"]},
    )
    assert response.status_code == 409


def test_generate_roster_rejects_non_positive_num_days(client: TestClient) -> None:
    response = client.post("/rosters", json={"start_date": "2026-08-03", "num_days": 0})
    assert response.status_code == 422


def test_manual_edit_rejects_inactive_staff(client: TestClient) -> None:
    ctx = _setup_simple_scenario(client)
    roster = client.post("/rosters", json={"start_date": "2026-08-03", "num_days": 1}).json()
    detail = client.get(f"/rosters/{roster['id']}").json()
    shift = detail["shifts"][0]

    staff_id = cast(dict[str, object], ctx["staff"])["id"]
    client.patch(f"/staff/{staff_id}", json={"active": False})

    response = client.patch(
        f"/rosters/{roster['id']}/shifts/{shift['id']}", json={"staff_id": staff_id}
    )
    assert response.status_code == 409


def test_manual_edit_allows_compatible_staggered_building_shifts(client: TestClient) -> None:
    """Same shift_index in two Buildings with staggered opening hours can be
    non-overlapping wall-clock windows — a manual edit must allow assigning both to the
    same staff member rather than rejecting on shift_index alone."""
    building_a = client.post(
        "/buildings", json={"name": "Building A", "opening_minutes": 480, "closing_minutes": 720}
    ).json()  # 08:00-12:00
    building_b = client.post(
        "/buildings",
        json={"name": "Building B", "opening_minutes": 780, "closing_minutes": 1020},
    ).json()  # 13:00-17:00, 60 minutes after Building A closes
    room_a = client.post(
        "/rooms", json={"name": "Room A", "building_id": building_a["id"], "tag_ids": []}
    ).json()
    room_b = client.post(
        "/rooms", json={"name": "Room B", "building_id": building_b["id"], "tag_ids": []}
    ).json()
    staff_a = client.post("/staff", json={"name": "Dr. Alice"}).json()
    client.post("/staff", json={"name": "Dr. Bob"}).json()

    roster = client.post("/rosters", json={"start_date": "2026-08-03", "num_days": 1}).json()
    detail = client.get(f"/rosters/{roster['id']}").json()
    shift_a = next(s for s in detail["shifts"] if s["room_id"] == room_a["id"])
    shift_b = next(s for s in detail["shifts"] if s["room_id"] == room_b["id"])
    assert shift_a["shift_index"] == shift_b["shift_index"] == 0

    client.patch(
        f"/rosters/{roster['id']}/shifts/{shift_a['id']}", json={"staff_id": staff_a["id"]}
    )
    response = client.patch(
        f"/rosters/{roster['id']}/shifts/{shift_b['id']}", json={"staff_id": staff_a["id"]}
    )
    assert response.status_code == 200


def test_manual_edit_rejects_overlap_across_differing_shift_indexes(client: TestClient) -> None:
    """Two shifts in different Buildings can overlap in wall-clock time even with
    *different* shift_index values, once opening hours are staggered — a manual edit must
    still catch that rather than only comparing shift_index."""
    building_a = client.post(
        "/buildings",
        json={"name": "Building A", "opening_minutes": 480, "closing_minutes": 960},
    ).json()  # 08:00-16:00 -> two 240-minute blocks: index 0 (08-12), index 1 (12-16)
    building_b = client.post(
        "/buildings",
        json={"name": "Building B", "opening_minutes": 780, "closing_minutes": 1020},
    ).json()  # 13:00-17:00 -> index 0 (13-17), which overlaps Building A's index 1 (12-16)
    room_a = client.post(
        "/rooms", json={"name": "Room A", "building_id": building_a["id"], "tag_ids": []}
    ).json()
    room_b = client.post(
        "/rooms", json={"name": "Room B", "building_id": building_b["id"], "tag_ids": []}
    ).json()
    staff_a = client.post("/staff", json={"name": "Dr. Alice"}).json()
    client.post("/staff", json={"name": "Dr. Bob"}).json()
    client.post("/staff", json={"name": "Dr. Carol"}).json()

    roster = client.post("/rosters", json={"start_date": "2026-08-03", "num_days": 1}).json()
    detail = client.get(f"/rosters/{roster['id']}").json()
    shift_a1 = next(
        s for s in detail["shifts"] if s["room_id"] == room_a["id"] and s["shift_index"] == 1
    )
    shift_b0 = next(
        s for s in detail["shifts"] if s["room_id"] == room_b["id"] and s["shift_index"] == 0
    )

    client.patch(
        f"/rosters/{roster['id']}/shifts/{shift_a1['id']}", json={"staff_id": staff_a["id"]}
    )
    response = client.patch(
        f"/rosters/{roster['id']}/shifts/{shift_b0['id']}", json={"staff_id": staff_a["id"]}
    )
    assert response.status_code == 409


def test_manual_edit_rejects_double_booking(client: TestClient) -> None:
    building = client.post(
        "/buildings", json={"name": "Hospital", "opening_minutes": 480, "closing_minutes": 720}
    ).json()
    room_a = client.post(
        "/rooms", json={"name": "Room A", "building_id": building["id"], "tag_ids": []}
    ).json()
    room_b = client.post(
        "/rooms", json={"name": "Room B", "building_id": building["id"], "tag_ids": []}
    ).json()
    staff_a = client.post("/staff", json={"name": "Dr. Alice"}).json()
    client.post("/staff", json={"name": "Dr. Bob"}).json()

    roster = client.post("/rosters", json={"start_date": "2026-08-03", "num_days": 1}).json()
    detail = client.get(f"/rosters/{roster['id']}").json()
    shift_a = next(s for s in detail["shifts"] if s["room_id"] == room_a["id"])
    shift_b = next(s for s in detail["shifts"] if s["room_id"] == room_b["id"])

    # Force both shifts onto staff_a: the first edit succeeds, the second must be rejected
    # since staff_a would then be double-booked in the same slot.
    client.patch(
        f"/rosters/{roster['id']}/shifts/{shift_a['id']}", json={"staff_id": staff_a["id"]}
    )
    response = client.patch(
        f"/rosters/{roster['id']}/shifts/{shift_b['id']}", json={"staff_id": staff_a["id"]}
    )
    assert response.status_code == 409
