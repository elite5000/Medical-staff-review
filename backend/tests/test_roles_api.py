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
