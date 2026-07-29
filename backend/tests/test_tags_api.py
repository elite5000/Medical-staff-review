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


def _create_building(client: TestClient, name: str = "Hospital") -> dict[str, object]:
    response = client.post(
        "/buildings", json={"name": name, "opening_minutes": 480, "closing_minutes": 1080}
    )
    assert response.status_code == 201
    return cast(dict[str, object], response.json())


def _create_room(
    client: TestClient, building_id: object, name: str, tag_ids: list[object] | None = None
) -> dict[str, object]:
    response = client.post(
        "/rooms", json={"name": name, "building_id": building_id, "tag_ids": tag_ids or []}
    )
    assert response.status_code == 201
    return cast(dict[str, object], response.json())


def test_apply_tag_to_rooms_is_additive(client: TestClient) -> None:
    """The bulk apply must union the Tag into each Room's existing tags — unlike
    PATCH /rooms/{id}, which full-replaces them."""
    surgery = _create_tag(client, name="Surgery")
    existing = _create_tag(client, name="General Practice")
    building = _create_building(client)
    untagged = _create_room(client, building["id"], "Room 1")
    already_tagged = _create_room(client, building["id"], "Room 2", [existing["id"]])

    response = client.post(
        f"/tags/{surgery['id']}/apply-to-rooms",
        json={"room_ids": [untagged["id"], already_tagged["id"]]},
    )
    assert response.status_code == 200
    by_id = {r["id"]: r for r in response.json()}
    assert {t["id"] for t in by_id[untagged["id"]]["tags"]} == {surgery["id"]}
    # Room 2's pre-existing tag survives alongside the newly applied one.
    assert {t["id"] for t in by_id[already_tagged["id"]]["tags"]} == {
        existing["id"],
        surgery["id"],
    }


def test_apply_tag_to_rooms_spans_multiple_buildings(client: TestClient) -> None:
    surgery = _create_tag(client, name="Surgery")
    building_a = _create_building(client, name="Building A")
    building_b = _create_building(client, name="Building B")
    room_a = _create_room(client, building_a["id"], "A1")
    room_b = _create_room(client, building_b["id"], "B1")
    untouched = _create_room(client, building_b["id"], "B2")

    response = client.post(
        f"/tags/{surgery['id']}/apply-to-rooms",
        json={"room_ids": [room_a["id"], room_b["id"]]},
    )
    assert response.status_code == 200
    assert {r["id"] for r in response.json()} == {room_a["id"], room_b["id"]}
    # A Room that wasn't selected keeps its (empty) tag list.
    assert client.get(f"/rooms/{untouched['id']}").json()["tags"] == []


def test_apply_tag_to_rooms_is_idempotent(client: TestClient) -> None:
    """Re-applying to a Room that already carries the Tag is a no-op for that Room, not an
    error — and must not create a duplicate room_tags row."""
    surgery = _create_tag(client, name="Surgery")
    building = _create_building(client)
    room = _create_room(client, building["id"], "Room 1")

    first = client.post(f"/tags/{surgery['id']}/apply-to-rooms", json={"room_ids": [room["id"]]})
    assert first.status_code == 200
    second = client.post(
        f"/tags/{surgery['id']}/apply-to-rooms", json={"room_ids": [room["id"], room["id"]]}
    )
    assert second.status_code == 200
    assert [t["id"] for t in second.json()[0]["tags"]] == [surgery["id"]]
    assert [t["id"] for t in client.get(f"/rooms/{room['id']}").json()["tags"]] == [surgery["id"]]


def test_apply_tag_to_rooms_unknown_tag_404(client: TestClient) -> None:
    building = _create_building(client)
    room = _create_room(client, building["id"], "Room 1")
    response = client.post("/tags/999/apply-to-rooms", json={"room_ids": [room["id"]]})
    assert response.status_code == 404


def test_apply_tag_to_rooms_unknown_room_422(client: TestClient) -> None:
    surgery = _create_tag(client, name="Surgery")
    building = _create_building(client)
    room = _create_room(client, building["id"], "Room 1")

    response = client.post(
        f"/tags/{surgery['id']}/apply-to-rooms", json={"room_ids": [room["id"], 999, 998]}
    )
    assert response.status_code == 422
    assert "998" in str(response.json()["detail"]) and "999" in str(response.json()["detail"])
    # Nothing is applied when any id is unknown — the whole call is rejected before commit.
    assert client.get(f"/rooms/{room['id']}").json()["tags"] == []


def test_apply_tag_to_rooms_empty_list(client: TestClient) -> None:
    surgery = _create_tag(client, name="Surgery")
    response = client.post(f"/tags/{surgery['id']}/apply-to-rooms", json={"room_ids": []})
    assert response.status_code == 200
    assert response.json() == []
