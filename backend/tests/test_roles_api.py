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
