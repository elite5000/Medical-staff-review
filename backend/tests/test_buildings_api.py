from typing import cast

from fastapi.testclient import TestClient


def _create_building(client: TestClient, **overrides: object) -> dict[str, object]:
    payload = {"name": "Hospital", "opening_minutes": 8 * 60, "closing_minutes": 18 * 60}
    payload.update(overrides)
    response = client.post("/buildings", json=payload)
    assert response.status_code == 201
    return cast(dict[str, object], response.json())


def test_create_and_get_building(client: TestClient) -> None:
    created = _create_building(client)
    response = client.get(f"/buildings/{created['id']}")
    assert response.status_code == 200
    assert response.json() == created


def test_list_buildings(client: TestClient) -> None:
    _create_building(client, name="Hospital")
    _create_building(client, name="Clinic")
    response = client.get("/buildings")
    assert response.status_code == 200
    names = {b["name"] for b in response.json()}
    assert names == {"Hospital", "Clinic"}


def test_update_building(client: TestClient) -> None:
    created = _create_building(client)
    response = client.patch(f"/buildings/{created['id']}", json={"opening_minutes": 7 * 60})
    assert response.status_code == 200
    assert response.json()["opening_minutes"] == 7 * 60
    assert response.json()["name"] == "Hospital"


def test_get_missing_building_404(client: TestClient) -> None:
    response = client.get("/buildings/999")
    assert response.status_code == 404


def test_delete_building(client: TestClient) -> None:
    created = _create_building(client)
    response = client.delete(f"/buildings/{created['id']}")
    assert response.status_code == 204
    assert client.get(f"/buildings/{created['id']}").status_code == 404


def test_create_building_rejects_closing_before_opening(client: TestClient) -> None:
    response = client.post(
        "/buildings", json={"name": "Bad Hours", "opening_minutes": 720, "closing_minutes": 480}
    )
    assert response.status_code == 422


def test_create_building_rejects_equal_opening_and_closing(client: TestClient) -> None:
    response = client.post(
        "/buildings", json={"name": "Bad Hours", "opening_minutes": 480, "closing_minutes": 480}
    )
    assert response.status_code == 422


def test_update_building_rejects_closing_before_opening(client: TestClient) -> None:
    created = _create_building(client)
    response = client.patch(
        f"/buildings/{created['id']}", json={"closing_minutes": created["opening_minutes"]}
    )
    assert response.status_code == 422


def test_create_building_rejects_hours_past_midnight(client: TestClient) -> None:
    # A window spanning past midnight would be treated as belonging entirely to one
    # calendar date by the solver and the manual-edit conflict check (both compare shifts
    # only within the same `date`), silently missing the overnight overlap.
    response = client.post(
        "/buildings", json={"name": "Overnight", "opening_minutes": 1380, "closing_minutes": 1620}
    )
    assert response.status_code == 422


def test_create_building_rejects_negative_opening_minutes(client: TestClient) -> None:
    response = client.post(
        "/buildings", json={"name": "Bad Hours", "opening_minutes": -60, "closing_minutes": 480}
    )
    assert response.status_code == 422


def test_update_building_rejects_hours_past_midnight(client: TestClient) -> None:
    created = _create_building(client)
    response = client.patch(f"/buildings/{created['id']}", json={"closing_minutes": 1620})
    assert response.status_code == 422


def test_create_building_rejects_duplicate_name(client: TestClient) -> None:
    _create_building(client, name="Hospital")
    response = client.post(
        "/buildings", json={"name": "Hospital", "opening_minutes": 480, "closing_minutes": 720}
    )
    assert response.status_code == 409


def test_delete_building_with_room_conflicts(client: TestClient) -> None:
    building = _create_building(client)
    room_response = client.post(
        "/rooms", json={"name": "Room 1", "building_id": building["id"], "tag_ids": []}
    )
    assert room_response.status_code == 201

    response = client.delete(f"/buildings/{building['id']}")
    assert response.status_code == 409
