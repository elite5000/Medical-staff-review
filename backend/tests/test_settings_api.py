from fastapi.testclient import TestClient


def test_get_settings_returns_defaults(client: TestClient) -> None:
    response = client.get("/settings")
    assert response.status_code == 200
    body = response.json()
    assert body["max_daily_minutes"] == 720


def test_update_settings_partial(client: TestClient) -> None:
    client.get("/settings")  # ensure the singleton row exists
    response = client.patch("/settings", json={"max_daily_minutes": 600})
    assert response.status_code == 200
    body = response.json()
    assert body["max_daily_minutes"] == 600
    # Untouched fields keep their previous value.
    assert body["shift_length_minutes"] == 240


def test_settings_singleton_persists_across_requests(client: TestClient) -> None:
    client.patch("/settings", json={"travel_time_minutes": 45})
    response = client.get("/settings")
    assert response.json()["travel_time_minutes"] == 45


def test_update_settings_rejects_non_positive_shift_length(client: TestClient) -> None:
    # A zero or negative shift length would make roster generation divide by zero.
    response = client.patch("/settings", json={"shift_length_minutes": 0})
    assert response.status_code == 422


def test_update_settings_rejects_negative_travel_time(client: TestClient) -> None:
    response = client.patch("/settings", json={"travel_time_minutes": -1})
    assert response.status_code == 422


def test_update_settings_rejects_non_positive_max_daily_minutes(client: TestClient) -> None:
    response = client.patch("/settings", json={"max_daily_minutes": 0})
    assert response.status_code == 422
