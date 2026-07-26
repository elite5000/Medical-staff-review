from typing import cast

from fastapi.testclient import TestClient


def _create_building(client: TestClient) -> dict[str, object]:
    response = client.post(
        "/buildings", json={"name": "Hospital", "opening_minutes": 480, "closing_minutes": 1080}
    )
    return cast(dict[str, object], response.json())


def test_create_room_with_multiple_tags(client: TestClient) -> None:
    building = _create_building(client)
    surgery = client.post("/tags", json={"name": "Surgery"}).json()
    ed = client.post("/tags", json={"name": "Emergency Department"}).json()

    response = client.post(
        "/rooms",
        json={
            "name": "Trauma Room",
            "building_id": building["id"],
            "tag_ids": [surgery["id"], ed["id"]],
        },
    )
    assert response.status_code == 201
    body = response.json()
    assert body["building_id"] == building["id"]
    assert {t["id"] for t in body["tags"]} == {surgery["id"], ed["id"]}


def test_create_room_unknown_building_404(client: TestClient) -> None:
    response = client.post("/rooms", json={"name": "Room 1", "building_id": 999, "tag_ids": []})
    assert response.status_code == 404


def test_create_room_unknown_tag_422(client: TestClient) -> None:
    building = _create_building(client)
    response = client.post(
        "/rooms", json={"name": "Room 1", "building_id": building["id"], "tag_ids": [999]}
    )
    assert response.status_code == 422


def test_update_room_tags(client: TestClient) -> None:
    building = _create_building(client)
    tag_a = client.post("/tags", json={"name": "General Practice"}).json()
    tag_b = client.post("/tags", json={"name": "Surgery"}).json()
    room = client.post(
        "/rooms", json={"name": "Room 1", "building_id": building["id"], "tag_ids": [tag_a["id"]]}
    ).json()

    response = client.patch(f"/rooms/{room['id']}", json={"tag_ids": [tag_b["id"]]})
    assert response.status_code == 200
    assert {t["id"] for t in response.json()["tags"]} == {tag_b["id"]}


def test_delete_room(client: TestClient) -> None:
    building = _create_building(client)
    room = client.post(
        "/rooms", json={"name": "Room 1", "building_id": building["id"], "tag_ids": []}
    ).json()
    assert client.delete(f"/rooms/{room['id']}").status_code == 204


def test_update_room_move_blocked_after_roster_history(client: TestClient) -> None:
    """A Room's retained Shift rows only store room_id/shift_index; wall-clock timing for
    them is derived from the Room's *current* Building, so moving it to a different
    Building after it appears in roster history would reinterpret that history under the
    wrong hours."""
    building_a = client.post(
        "/buildings", json={"name": "Building A", "opening_minutes": 480, "closing_minutes": 720}
    ).json()
    building_b = client.post(
        "/buildings", json={"name": "Building B", "opening_minutes": 480, "closing_minutes": 720}
    ).json()
    room = client.post(
        "/rooms", json={"name": "Room 1", "building_id": building_a["id"], "tag_ids": []}
    ).json()
    client.post("/staff", json={"name": "Dr. Alice"})

    roster = client.post("/rosters", json={"start_date": "2026-08-03", "num_days": 1}).json()
    detail = client.get(f"/rosters/{roster['id']}").json()
    assert any(s["room_id"] == room["id"] for s in detail["shifts"])

    response = client.patch(f"/rooms/{room['id']}", json={"building_id": building_b["id"]})
    assert response.status_code == 409

    # Other fields, and a no-op "move" to the same Building, remain editable.
    unchanged = client.patch(f"/rooms/{room['id']}", json={"name": "Room 1 (renamed)"})
    assert unchanged.status_code == 200
    noop = client.patch(f"/rooms/{room['id']}", json={"building_id": building_a["id"]})
    assert noop.status_code == 200


def test_delete_room_blocked_by_violation_history_without_shifts(client: TestClient) -> None:
    """A Room can appear in a generated Roster's history purely as a ROOM_UNFILLED
    violation, with no Shift row ever created for it (e.g. no Staff exists at all) — the
    delete guard must still catch that, not just look for Shift rows."""
    building = client.post(
        "/buildings", json={"name": "Hospital", "opening_minutes": 480, "closing_minutes": 720}
    ).json()
    room = client.post(
        "/rooms", json={"name": "Room 1", "building_id": building["id"], "tag_ids": []}
    ).json()

    roster = client.post("/rosters", json={"start_date": "2026-08-03", "num_days": 1}).json()
    detail = client.get(f"/rosters/{roster['id']}").json()
    assert any(v["room_id"] == room["id"] for v in detail["violations"])
    assert all(s["room_id"] != room["id"] for s in detail["shifts"])

    response = client.delete(f"/rooms/{room['id']}")
    assert response.status_code == 409
