from datetime import date, datetime
from typing import cast

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models.roster import Roster
from app.models.shift import Shift


def _create_role(client: TestClient, name: str = "Senior Fellow") -> dict[str, object]:
    return cast(dict[str, object], client.post("/roles", json={"name": name}).json())


def test_create_staff_with_roles_and_preferred_days(client: TestClient) -> None:
    role = _create_role(client)
    response = client.post(
        "/staff",
        json={
            "name": "Dr. Alice",
            "role_ids": [role["id"]],
            "preferred_days": [
                {"week": 0, "day_of_week": 0},
                {"week": 0, "day_of_week": 2},
                {"week": 1, "day_of_week": 4},
            ],
        },
    )
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Dr. Alice"
    assert body["active"] is True
    assert [r["id"] for r in body["roles"]] == [role["id"]]
    assert body["preferred_days"] == [
        {"week": 0, "day_of_week": 0},
        {"week": 0, "day_of_week": 2},
        {"week": 1, "day_of_week": 4},
    ]
    assert body["unavailabilities"] == []


def test_create_staff_duplicate_preferred_day_rejected(client: TestClient) -> None:
    response = client.post(
        "/staff",
        json={
            "name": "Dr. Alice",
            "preferred_days": [{"week": 0, "day_of_week": 0}, {"week": 0, "day_of_week": 0}],
        },
    )
    assert response.status_code == 422


def test_create_staff_invalid_day_of_week_rejected(client: TestClient) -> None:
    response = client.post(
        "/staff",
        json={"name": "Dr. Alice", "preferred_days": [{"week": 0, "day_of_week": 7}]},
    )
    assert response.status_code == 422


def test_create_staff_invalid_week_rejected(client: TestClient) -> None:
    response = client.post(
        "/staff",
        json={"name": "Dr. Alice", "preferred_days": [{"week": 2, "day_of_week": 0}]},
    )
    assert response.status_code == 422


def test_bulk_create_staff(client: TestClient) -> None:
    response = client.post("/staff/bulk", json={"names": ["Dr. Alice", "Dr. Bob"]})
    assert response.status_code == 201
    body = response.json()
    assert [s["name"] for s in body["created"]] == ["Dr. Alice", "Dr. Bob"]
    # Bulk-add is names only: everyone starts active, with no roles and no preferred days.
    assert all(s["active"] is True for s in body["created"])
    assert all(s["roles"] == [] for s in body["created"])
    assert all(s["preferred_days"] == [] for s in body["created"])
    assert all(s["unavailabilities"] == [] for s in body["created"])
    assert body["skipped"] == []
    assert len(client.get("/staff").json()) == 2


def test_bulk_create_staff_trims_and_drops_blank_lines(client: TestClient) -> None:
    response = client.post(
        "/staff/bulk", json={"names": ["  Dr. Alice  ", "", "   ", "\tDr. Bob\n"]}
    )
    assert response.status_code == 201
    assert [s["name"] for s in response.json()["created"]] == ["Dr. Alice", "Dr. Bob"]


def test_bulk_create_staff_keeps_repeated_names(client: TestClient) -> None:
    """Staff.name has no UNIQUE constraint — two people can share a name, so a repeat is
    created rather than deduped or skipped."""
    client.post("/staff", json={"name": "Dr. Alice"})
    response = client.post("/staff/bulk", json={"names": ["Dr. Alice", "Dr. Alice"]})
    assert response.status_code == 201
    body = response.json()
    assert [s["name"] for s in body["created"]] == ["Dr. Alice", "Dr. Alice"]
    assert body["skipped"] == []
    assert len(client.get("/staff").json()) == 3


def test_bulk_create_staff_empty_list(client: TestClient) -> None:
    response = client.post("/staff/bulk", json={"names": []})
    assert response.status_code == 201
    assert response.json() == {"created": [], "skipped": []}
    assert client.get("/staff").json() == []


def test_update_staff_roles_and_preferred_days(client: TestClient) -> None:
    role_a = _create_role(client, "Senior Fellow")
    role_b = _create_role(client, "Emergency Medicine")
    staff = client.post("/staff", json={"name": "Dr. Alice", "role_ids": [role_a["id"]]}).json()

    response = client.patch(
        f"/staff/{staff['id']}",
        json={
            "role_ids": [role_b["id"]],
            "preferred_days": [{"week": 1, "day_of_week": 1}],
            "active": False,
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert [r["id"] for r in body["roles"]] == [role_b["id"]]
    assert body["preferred_days"] == [{"week": 1, "day_of_week": 1}]
    assert body["active"] is False


def test_preferred_day_can_differ_between_weeks(client: TestClient) -> None:
    """The same day_of_week may be preferred in one week but not the other."""
    staff = client.post(
        "/staff",
        json={
            "name": "Dr. Alice",
            "preferred_days": [
                {"week": 0, "day_of_week": 0},
                {"week": 1, "day_of_week": 1},
            ],
        },
    ).json()
    body = client.get(f"/staff/{staff['id']}").json()
    assert body["preferred_days"] == [
        {"week": 0, "day_of_week": 0},
        {"week": 1, "day_of_week": 1},
    ]


def test_update_preferred_days_overlapping_with_existing(client: TestClient) -> None:
    """Regression test: updating preferred_days used to 500 whenever the new set kept a day
    that was already preferred, because the old row's delete and the new row's insert could
    race under the (staff_id, week, day_of_week) UNIQUE constraint."""
    staff = client.post(
        "/staff",
        json={"name": "Dr. Alice", "preferred_days": [{"week": 0, "day_of_week": 0}]},
    ).json()

    response = client.patch(
        f"/staff/{staff['id']}",
        json={
            "preferred_days": [
                {"week": 0, "day_of_week": 0},
                {"week": 1, "day_of_week": 4},
            ]
        },
    )
    assert response.status_code == 200
    assert response.json()["preferred_days"] == [
        {"week": 0, "day_of_week": 0},
        {"week": 1, "day_of_week": 4},
    ]


def test_add_and_remove_unavailability(client: TestClient) -> None:
    staff = client.post("/staff", json={"name": "Dr. Alice"}).json()

    response = client.post(
        f"/staff/{staff['id']}/unavailabilities",
        json={"start_date": "2026-08-01", "end_date": "2026-08-05", "reason": "Leave"},
    )
    assert response.status_code == 201
    unavailability = response.json()
    assert client.get(f"/staff/{staff['id']}").json()["unavailabilities"] == [unavailability]

    delete_response = client.delete(f"/staff/{staff['id']}/unavailabilities/{unavailability['id']}")
    assert delete_response.status_code == 204
    assert client.get(f"/staff/{staff['id']}").json()["unavailabilities"] == []


def test_unavailability_end_before_start_rejected(client: TestClient) -> None:
    staff = client.post("/staff", json={"name": "Dr. Alice"}).json()
    response = client.post(
        f"/staff/{staff['id']}/unavailabilities",
        json={"start_date": "2026-08-05", "end_date": "2026-08-01"},
    )
    assert response.status_code == 422


def test_delete_staff_with_shift_history_conflicts(client: TestClient, db_session: Session) -> None:
    building = client.post(
        "/buildings", json={"name": "Hospital", "opening_minutes": 480, "closing_minutes": 1080}
    ).json()
    room = client.post(
        "/rooms", json={"name": "Room 1", "building_id": building["id"], "tag_ids": []}
    ).json()
    staff = client.post("/staff", json={"name": "Dr. Alice"}).json()

    roster = Roster(
        start_date=date(2026, 8, 1),
        end_date=date(2026, 8, 14),
        generated_at=datetime(2026, 7, 25, 12, 0, 0),
    )
    db_session.add(roster)
    db_session.flush()
    db_session.add(
        Shift(
            roster_id=roster.id,
            room_id=room["id"],
            staff_id=staff["id"],
            date=date(2026, 8, 1),
            shift_index=0,
        )
    )
    db_session.commit()

    response = client.delete(f"/staff/{staff['id']}")
    assert response.status_code == 409
