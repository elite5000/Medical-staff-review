from datetime import date, datetime

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models.roster import Roster, RosterViolation, ViolationType


def _setup(client: TestClient) -> dict[str, dict[str, object]]:
    role = client.post("/roles", json={"name": "Senior Fellow"}).json()
    building = client.post(
        "/buildings", json={"name": "Hospital", "opening_minutes": 480, "closing_minutes": 1080}
    ).json()
    tag = client.post("/tags", json={"name": "Emergency Department"}).json()
    return {"role": role, "building": building, "tag": tag}


def test_minimum_count_rule_on_building(client: TestClient) -> None:
    ctx = _setup(client)
    response = client.post(
        "/rules",
        json={
            "name": "ED minimum staffing",
            "rule_type": "minimum_count",
            "role_id": ctx["role"]["id"],
            "building_id": ctx["building"]["id"],
            "minimum_count": 1,
        },
    )
    assert response.status_code == 201
    assert response.json()["rule_type"] == "minimum_count"


def test_minimum_count_rule_on_tag(client: TestClient) -> None:
    ctx = _setup(client)
    response = client.post(
        "/rules",
        json={
            "name": "ED minimum staffing",
            "rule_type": "minimum_count",
            "role_id": ctx["role"]["id"],
            "tag_id": ctx["tag"]["id"],
            "minimum_count": 1,
        },
    )
    assert response.status_code == 201


def test_minimum_count_rule_requires_exactly_one_target(client: TestClient) -> None:
    ctx = _setup(client)
    both = client.post(
        "/rules",
        json={
            "name": "ED minimum staffing",
            "rule_type": "minimum_count",
            "role_id": ctx["role"]["id"],
            "building_id": ctx["building"]["id"],
            "tag_id": ctx["tag"]["id"],
            "minimum_count": 1,
        },
    )
    assert both.status_code == 422

    neither = client.post(
        "/rules",
        json={
            "name": "ED minimum staffing",
            "rule_type": "minimum_count",
            "role_id": ctx["role"]["id"],
            "minimum_count": 1,
        },
    )
    assert neither.status_code == 422


def test_minimum_count_rule_requires_positive_count(client: TestClient) -> None:
    ctx = _setup(client)
    response = client.post(
        "/rules",
        json={
            "name": "ED minimum staffing",
            "rule_type": "minimum_count",
            "role_id": ctx["role"]["id"],
            "building_id": ctx["building"]["id"],
            "minimum_count": 0,
        },
    )
    assert response.status_code == 422


def test_eligibility_restriction_rule_on_tag(client: TestClient) -> None:
    ctx = _setup(client)
    response = client.post(
        "/rules",
        json={
            "name": "ED eligibility",
            "rule_type": "eligibility_restriction",
            "role_id": ctx["role"]["id"],
            "tag_id": ctx["tag"]["id"],
        },
    )
    assert response.status_code == 201


def test_eligibility_restriction_rule_rejects_building_target(client: TestClient) -> None:
    ctx = _setup(client)
    response = client.post(
        "/rules",
        json={
            "name": "ED eligibility",
            "rule_type": "eligibility_restriction",
            "role_id": ctx["role"]["id"],
            "building_id": ctx["building"]["id"],
        },
    )
    assert response.status_code == 422


def test_eligibility_restriction_rule_requires_tag(client: TestClient) -> None:
    ctx = _setup(client)
    response = client.post(
        "/rules",
        json={
            "name": "ED eligibility",
            "rule_type": "eligibility_restriction",
            "role_id": ctx["role"]["id"],
        },
    )
    assert response.status_code == 422


def test_create_rule_unknown_role_422(client: TestClient) -> None:
    ctx = _setup(client)
    response = client.post(
        "/rules",
        json={
            "name": "ED minimum staffing",
            "rule_type": "minimum_count",
            "role_id": 999,
            "building_id": ctx["building"]["id"],
            "minimum_count": 1,
        },
    )
    assert response.status_code == 422


def test_delete_rule_referenced_by_violation_history_conflicts(
    client: TestClient, db_session: Session
) -> None:
    ctx = _setup(client)
    rule = client.post(
        "/rules",
        json={
            "name": "ED minimum staffing",
            "rule_type": "minimum_count",
            "role_id": ctx["role"]["id"],
            "building_id": ctx["building"]["id"],
            "minimum_count": 1,
        },
    ).json()

    roster = Roster(
        start_date=date(2026, 8, 1),
        end_date=date(2026, 8, 14),
        generated_at=datetime(2026, 7, 25, 12, 0, 0),
        has_violations=True,
    )
    db_session.add(roster)
    db_session.flush()
    db_session.add(
        RosterViolation(
            roster_id=roster.id,
            violation_type=ViolationType.MINIMUM_COUNT_UNMET,
            rule_id=rule["id"],
            date=date(2026, 8, 1),
            shift_index=0,
        )
    )
    db_session.commit()

    response = client.delete(f"/rules/{rule['id']}")
    assert response.status_code == 409
