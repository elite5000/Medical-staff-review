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


def test_bulk_create_tags(client: TestClient) -> None:
    response = client.post("/tags/bulk", json={"names": ["Surgery", "Emergency Department"]})
    assert response.status_code == 201
    body = response.json()
    assert [t["name"] for t in body["created"]] == ["Surgery", "Emergency Department"]
    assert body["skipped"] == []
    assert {t["name"] for t in client.get("/tags").json()} == {"Surgery", "Emergency Department"}


def test_bulk_create_tags_trims_and_drops_blank_lines(client: TestClient) -> None:
    """The client splits a pasted block on newlines, so trailing newlines and indented lines
    arrive as blank/padded entries — the API filters them too rather than trusting it."""
    response = client.post(
        "/tags/bulk", json={"names": ["  Surgery  ", "", "   ", "\tEmergency Department\n"]}
    )
    assert response.status_code == 201
    assert [t["name"] for t in response.json()["created"]] == ["Surgery", "Emergency Department"]


def test_bulk_create_tags_skips_names_that_already_exist(client: TestClient) -> None:
    _create_tag(client, name="Surgery")
    response = client.post("/tags/bulk", json={"names": ["Surgery", "General Practice"]})
    assert response.status_code == 201
    body = response.json()
    assert [t["name"] for t in body["created"]] == ["General Practice"]
    assert body["skipped"] == ["Surgery"]
    assert len(client.get("/tags").json()) == 2  # the existing Tag isn't duplicated


def test_bulk_create_tags_collapses_duplicates_within_the_batch(client: TestClient) -> None:
    """A name repeated inside one paste must produce a single Tag rather than a UNIQUE
    violation against itself — and it isn't reported as skipped, since it didn't exist."""
    response = client.post("/tags/bulk", json={"names": ["Surgery", "Surgery"]})
    assert response.status_code == 201
    body = response.json()
    assert [t["name"] for t in body["created"]] == ["Surgery"]
    assert body["skipped"] == []


def test_bulk_create_tags_empty_list(client: TestClient) -> None:
    response = client.post("/tags/bulk", json={"names": []})
    assert response.status_code == 201
    assert response.json() == {"created": [], "skipped": []}
    assert client.get("/tags").json() == []
