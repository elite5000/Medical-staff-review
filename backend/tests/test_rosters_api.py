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


def test_regenerate_rejects_stale_roster(client: TestClient) -> None:
    """Only the most recent generation for a date range may be regenerated — see
    RosterListPage.svelte's latestIdByRange, which the backend must also enforce so a
    stale tab or a direct API call can't supersede a newer generation's pins/edits."""
    _setup_simple_scenario(client)
    first = client.post("/rosters", json={"start_date": "2026-08-03", "num_days": 1}).json()
    second = client.post(f"/rosters/{first['id']}/regenerate")
    assert second.status_code == 201

    response = client.post(f"/rosters/{first['id']}/regenerate")
    assert response.status_code == 409


def test_manual_edit_rejects_historical_roster(client: TestClient) -> None:
    """Older generations for a date range are read-only history once a newer generation
    exists — matching RosterListPage.svelte's read-only treatment of non-latest rows."""
    ctx = _setup_simple_scenario(client)
    first = client.post("/rosters", json={"start_date": "2026-08-03", "num_days": 1}).json()
    first_detail = client.get(f"/rosters/{first['id']}").json()
    shift = first_detail["shifts"][0]

    regenerate_response = client.post(f"/rosters/{first['id']}/regenerate")
    assert regenerate_response.status_code == 201

    response = client.patch(
        f"/rosters/{first['id']}/shifts/{shift['id']}",
        json={"staff_id": cast(dict[str, object], ctx["staff"])["id"]},
    )
    assert response.status_code == 409


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


def test_generate_roster_rejects_num_days_beyond_a_fortnight(client: TestClient) -> None:
    # The solver's fixed objective weights only guarantee strict soft-goal priority for
    # rosters up to 14 days (see the comment on RosterGenerateRequest.num_days).
    response = client.post("/rosters", json={"start_date": "2026-08-03", "num_days": 15})
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


def test_manual_edit_rejects_exceeding_max_daily_hours(client: TestClient) -> None:
    """Every assigned block counts toward Max Daily Hours, even ones that don't overlap or
    need Travel Time to fit alongside the staff member's other shifts that day — a manual
    edit must enforce the daily cap too, not just time conflicts."""
    staff_a = client.post("/staff", json={"name": "Dr. Alice"}).json()
    # Bob prefers a day other than the roster date (2026-08-03 is a Monday, day_of_week 0),
    # so the solver only assigns him the one block Alice's Max Daily Hours cap can't absorb
    # — deterministically leaving Alice with exactly 3 of the 4 blocks.
    staff_b = client.post(
        "/staff",
        json={"name": "Dr. Bob", "preferred_days": [{"week": 0, "day_of_week": 2}]},
    ).json()

    rooms = []
    for i, (opening, closing) in enumerate([(0, 240), (300, 540), (600, 840), (900, 1140)]):
        building = client.post(
            "/buildings",
            json={
                "name": f"Building {i}",
                "opening_minutes": opening,
                "closing_minutes": closing,
            },
        ).json()
        room = client.post(
            "/rooms", json={"name": f"Room {i}", "building_id": building["id"], "tag_ids": []}
        ).json()
        rooms.append(room)

    roster = client.post("/rosters", json={"start_date": "2026-08-03", "num_days": 1}).json()
    detail = client.get(f"/rosters/{roster['id']}").json()
    assert len(detail["shifts"]) == 4

    alice_shifts = [s for s in detail["shifts"] if s["staff_id"] == staff_a["id"]]
    bob_shifts = [s for s in detail["shifts"] if s["staff_id"] == staff_b["id"]]
    assert len(alice_shifts) == 3
    assert len(bob_shifts) == 1

    response = client.patch(
        f"/rosters/{roster['id']}/shifts/{bob_shifts[0]['id']}", json={"staff_id": staff_a["id"]}
    )
    assert response.status_code == 409
    assert "Max Daily Hours" in response.json()["detail"]


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
