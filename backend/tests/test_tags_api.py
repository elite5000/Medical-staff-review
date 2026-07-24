from typing import cast

from fastapi.testclient import TestClient


def _create_tag(client: TestClient, name: str = "Surgery") -> dict[str, object]:
    response = client.post("/tags", json={"name": name})
    assert response.status_code == 201
    return cast(dict[str, object], response.json())


def test_create_list_get_tag(client: TestClient) -> None:
    created = _create_tag(client)
    assert client.get("/tags").json() == [created]
    assert client.get(f"/tags/{created['id']}").json() == created


def test_update_tag(client: TestClient) -> None:
    created = _create_tag(client)
    response = client.patch(f"/tags/{created['id']}", json={"name": "Emergency Department"})
    assert response.status_code == 200
    assert response.json()["name"] == "Emergency Department"


def test_delete_tag(client: TestClient) -> None:
    created = _create_tag(client)
    assert client.delete(f"/tags/{created['id']}").status_code == 204
    assert client.get(f"/tags/{created['id']}").status_code == 404


def test_delete_tag_in_use_by_room_conflicts(client: TestClient) -> None:
    tag = _create_tag(client)
    building = client.post(
        "/buildings", json={"name": "Hospital", "opening_minutes": 480, "closing_minutes": 1080}
    ).json()
    client.post(
        "/rooms",
        json={"name": "Room 1", "building_id": building["id"], "tag_ids": [tag["id"]]},
    )
    assert client.delete(f"/tags/{tag['id']}").status_code == 409


def test_create_tag_rejects_duplicate_name(client: TestClient) -> None:
    _create_tag(client, name="Surgery")
    response = client.post("/tags", json={"name": "Surgery"})
    assert response.status_code == 409


def test_update_tag_rejects_duplicate_name(client: TestClient) -> None:
    _create_tag(client, name="Surgery")
    other = _create_tag(client, name="General Practice")
    response = client.patch(f"/tags/{other['id']}", json={"name": "Surgery"})
    assert response.status_code == 409
