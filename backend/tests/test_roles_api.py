from typing import cast

from fastapi.testclient import TestClient


def _create_role(client: TestClient, name: str = "Senior Fellow") -> dict[str, object]:
    response = client.post("/roles", json={"name": name})
    assert response.status_code == 201
    return cast(dict[str, object], response.json())


def test_create_list_get_role(client: TestClient) -> None:
    created = _create_role(client)
    assert client.get("/roles").json() == [created]
    assert client.get(f"/roles/{created['id']}").json() == created


def test_delete_role_in_use_by_staff_conflicts(client: TestClient) -> None:
    role = _create_role(client)
    client.post("/staff", json={"name": "Dr. Alice", "role_ids": [role["id"]]})
    assert client.delete(f"/roles/{role['id']}").status_code == 409


def test_delete_unused_role(client: TestClient) -> None:
    role = _create_role(client)
    assert client.delete(f"/roles/{role['id']}").status_code == 204


def test_create_role_rejects_duplicate_name(client: TestClient) -> None:
    _create_role(client, name="Senior Fellow")
    response = client.post("/roles", json={"name": "Senior Fellow"})
    assert response.status_code == 409


def test_update_role_rejects_duplicate_name(client: TestClient) -> None:
    _create_role(client, name="Senior Fellow")
    other = _create_role(client, name="Junior Fellow")
    response = client.patch(f"/roles/{other['id']}", json={"name": "Senior Fellow"})
    assert response.status_code == 409


def test_bulk_create_roles(client: TestClient) -> None:
    response = client.post("/roles/bulk", json={"names": ["Senior Fellow", "Nurse Practitioner"]})
    assert response.status_code == 201
    body = response.json()
    assert [r["name"] for r in body["created"]] == ["Senior Fellow", "Nurse Practitioner"]
    assert body["skipped"] == []
    assert {r["name"] for r in client.get("/roles").json()} == {
        "Senior Fellow",
        "Nurse Practitioner",
    }


def test_bulk_create_roles_trims_and_drops_blank_lines(client: TestClient) -> None:
    response = client.post(
        "/roles/bulk", json={"names": ["  Senior Fellow  ", "", "   ", "\tJunior Fellow\n"]}
    )
    assert response.status_code == 201
    assert [r["name"] for r in response.json()["created"]] == ["Senior Fellow", "Junior Fellow"]


def test_bulk_create_roles_skips_names_that_already_exist(client: TestClient) -> None:
    _create_role(client, name="Senior Fellow")
    response = client.post("/roles/bulk", json={"names": ["Senior Fellow", "Junior Fellow"]})
    assert response.status_code == 201
    body = response.json()
    assert [r["name"] for r in body["created"]] == ["Junior Fellow"]
    assert body["skipped"] == ["Senior Fellow"]
    assert len(client.get("/roles").json()) == 2  # the existing Role isn't duplicated


def test_bulk_create_roles_collapses_duplicates_within_the_batch(client: TestClient) -> None:
    response = client.post("/roles/bulk", json={"names": ["Senior Fellow", "Senior Fellow"]})
    assert response.status_code == 201
    body = response.json()
    assert [r["name"] for r in body["created"]] == ["Senior Fellow"]
    assert body["skipped"] == []


def test_bulk_create_roles_empty_list(client: TestClient) -> None:
    response = client.post("/roles/bulk", json={"names": []})
    assert response.status_code == 201
    assert response.json() == {"created": [], "skipped": []}
    assert client.get("/roles").json() == []


def _create_staff(
    client: TestClient, name: str, role_ids: list[object] | None = None
) -> dict[str, object]:
    response = client.post("/staff", json={"name": name, "role_ids": role_ids or []})
    assert response.status_code == 201
    return cast(dict[str, object], response.json())


def _role_names(staff: dict[str, object]) -> list[str]:
    return sorted(r["name"] for r in cast(list[dict[str, str]], staff["roles"]))


def test_apply_role_to_staff_is_additive(client: TestClient) -> None:
    """The role is added to everyone selected without disturbing roles they already hold."""
    senior = _create_role(client, "Senior Fellow")
    nurse = _create_role(client, "Nurse Practitioner")
    alice = _create_staff(client, "Dr. Alice", [nurse["id"]])
    bob = _create_staff(client, "Dr. Bob")
    carol = _create_staff(client, "Dr. Carol")  # not selected — must be left alone

    response = client.post(
        f"/roles/{senior['id']}/apply-to-staff",
        json={"staff_ids": [alice["id"], bob["id"]]},
    )
    assert response.status_code == 200
    body = response.json()
    assert [s["name"] for s in body] == ["Dr. Alice", "Dr. Bob"]
    assert _role_names(body[0]) == ["Nurse Practitioner", "Senior Fellow"]
    assert _role_names(body[1]) == ["Senior Fellow"]
    # Full StaffRead shape, not a trimmed one — the client swaps these straight into its list.
    assert body[0]["preferred_days"] == []
    assert body[0]["unavailabilities"] == []

    assert _role_names(client.get(f"/staff/{alice['id']}").json()) == [
        "Nurse Practitioner",
        "Senior Fellow",
    ]
    assert _role_names(client.get(f"/staff/{carol['id']}").json()) == []


def test_apply_role_to_staff_is_idempotent(client: TestClient) -> None:
    """Reapplying to someone who already holds the role is a no-op for them, not an error."""
    role = _create_role(client)
    alice = _create_staff(client, "Dr. Alice", [role["id"]])
    bob = _create_staff(client, "Dr. Bob")

    response = client.post(
        f"/roles/{role['id']}/apply-to-staff",
        json={"staff_ids": [alice["id"], bob["id"]]},
    )
    assert response.status_code == 200
    assert [_role_names(s) for s in response.json()] == [["Senior Fellow"], ["Senior Fellow"]]

    # And a second identical apply still changes nothing — no duplicate staff_roles rows.
    repeat = client.post(
        f"/roles/{role['id']}/apply-to-staff",
        json={"staff_ids": [alice["id"], bob["id"]]},
    )
    assert repeat.status_code == 200
    assert [_role_names(s) for s in repeat.json()] == [["Senior Fellow"], ["Senior Fellow"]]


def test_apply_unknown_role_to_staff_404s(client: TestClient) -> None:
    alice = _create_staff(client, "Dr. Alice")
    response = client.post("/roles/999/apply-to-staff", json={"staff_ids": [alice["id"]]})
    assert response.status_code == 404


def test_apply_role_to_unknown_staff_422s_and_applies_nothing(client: TestClient) -> None:
    role = _create_role(client)
    alice = _create_staff(client, "Dr. Alice")

    response = client.post(
        f"/roles/{role['id']}/apply-to-staff",
        json={"staff_ids": [alice["id"], 999]},
    )
    assert response.status_code == 422
    assert "999" in str(response.json()["detail"])
    # Rejected wholesale: the known id in the same request must not have been applied either.
    assert _role_names(client.get(f"/staff/{alice['id']}").json()) == []


def test_apply_role_to_empty_staff_list_is_a_no_op(client: TestClient) -> None:
    role = _create_role(client)
    _create_staff(client, "Dr. Alice")

    response = client.post(f"/roles/{role['id']}/apply-to-staff", json={"staff_ids": []})
    assert response.status_code == 200
    assert response.json() == []
    # Still deletable, i.e. no staff picked the role up.
    assert client.delete(f"/roles/{role['id']}").status_code == 204
