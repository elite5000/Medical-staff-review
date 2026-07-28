import pytest
from fastapi.testclient import TestClient

from app.config import settings


def test_health_ignores_pairing_token(client: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "pairing_token", "secret")
    response = client.get("/health")
    assert response.status_code == 200


def test_request_rejected_without_pairing_token(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(settings, "pairing_token", "secret")
    response = client.get("/buildings")
    assert response.status_code == 401


def test_request_rejected_with_wrong_pairing_token(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(settings, "pairing_token", "secret")
    response = client.get("/buildings", headers={"Authorization": "Bearer wrong"})
    assert response.status_code == 401


def test_request_accepted_with_correct_pairing_token(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(settings, "pairing_token", "secret")
    response = client.get("/buildings", headers={"Authorization": "Bearer secret"})
    assert response.status_code == 200


def test_request_accepted_when_no_pairing_token_configured(client: TestClient) -> None:
    assert settings.pairing_token is None
    response = client.get("/buildings")
    assert response.status_code == 200
