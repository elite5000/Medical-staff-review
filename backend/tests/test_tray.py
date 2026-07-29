"""Covers the pure, non-OS-integration logic in app.desktop.tray: certificate generation/
fingerprinting, the QR pairing payload, LAN IP candidate selection, path resolution, and the
tray icon image. Deliberately does NOT cover the Tk windows, pystray icon/menu, uvicorn
server thread, or Alembic migration run — see the module's own docstring for why those only
make sense to verify by running the packaged .exe."""

import json
import socket
from collections.abc import Generator
from datetime import UTC, datetime
from pathlib import Path

import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa

from app.config import settings
from app.desktop import tray


@pytest.fixture
def data_dir(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.setattr(tray, "get_data_dir", lambda: tmp_path)
    return tmp_path


def test_ensure_certificate_generates_cert_and_key(data_dir: Path) -> None:
    cert_path, key_path = tray._ensure_certificate()

    assert cert_path == data_dir / "cert.pem"
    assert key_path == data_dir / "key.pem"
    assert cert_path.exists()
    assert key_path.exists()

    cert = x509.load_pem_x509_certificate(cert_path.read_bytes())
    assert cert.subject.rfc4514_string() == "CN=Medical Staff Review"
    public_key = cert.public_key()
    assert isinstance(public_key, rsa.RSAPublicKey)
    assert public_key.key_size == 2048
    validity_days = (cert.not_valid_after_utc - cert.not_valid_before_utc).days
    assert validity_days == pytest.approx(3650, abs=1)
    assert cert.not_valid_before_utc <= datetime.now(UTC)


def test_ensure_certificate_is_idempotent(data_dir: Path) -> None:
    cert_path, key_path = tray._ensure_certificate()
    first_cert_bytes = cert_path.read_bytes()
    first_key_bytes = key_path.read_bytes()

    second_cert_path, second_key_path = tray._ensure_certificate()

    assert second_cert_path == cert_path
    assert second_key_path == key_path
    # Regenerating would produce a different key/serial number — bytes must be untouched.
    assert cert_path.read_bytes() == first_cert_bytes
    assert key_path.read_bytes() == first_key_bytes


def test_cert_fingerprint_matches_the_certificate(data_dir: Path) -> None:
    cert_path, _ = tray._ensure_certificate()

    fingerprint = tray._cert_fingerprint(cert_path)

    cert = x509.load_pem_x509_certificate(cert_path.read_bytes())
    expected = cert.fingerprint(hashes.SHA256()).hex()
    assert fingerprint == expected
    assert len(fingerprint) == 64


def test_connection_payload_includes_host_port_token_and_fingerprint(
    data_dir: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(settings, "pairing_token", "test-pairing-token")

    payload = json.loads(tray._connection_payload("192.168.1.42"))

    cert_path, _ = tray._ensure_certificate()
    assert payload == {
        "host": "192.168.1.42",
        "port": tray.PORT,
        "token": "test-pairing-token",
        "cert_fingerprint": tray._cert_fingerprint(cert_path),
    }


def test_tray_icon_image_is_a_64x64_rgba_image() -> None:
    image = tray._tray_icon_image()

    assert image.size == (64, 64)
    assert image.mode == "RGBA"


def test_backend_root_resolves_to_the_directory_containing_alembic_ini() -> None:
    root = tray._backend_root()

    assert (root / "alembic.ini").exists()
    assert (root / "migrations").is_dir()


class _FakeSocket:
    def __init__(self, connect_error: OSError | None = None) -> None:
        self._connect_error = connect_error

    def connect(self, _address: tuple[str, int]) -> None:
        if self._connect_error:
            raise self._connect_error

    def getsockname(self) -> tuple[str, int]:
        return ("127.0.0.1", 0)

    def close(self) -> None:
        pass


@pytest.fixture
def no_route(monkeypatch: pytest.MonkeyPatch) -> Generator[None]:
    """Makes the route-detection socket.connect() fail, so _candidate_lan_ips falls through
    to its hostname/getaddrinfo-based lookup — the part these tests are exercising."""
    monkeypatch.setattr(socket, "socket", lambda *a, **k: _FakeSocket(connect_error=OSError()))
    monkeypatch.setattr(socket, "gethostname", lambda: "some-host")
    monkeypatch.setattr(socket, "getfqdn", lambda: "some-host.local")
    yield


def test_candidate_lan_ips_prefers_private_over_public(
    no_route: None, monkeypatch: pytest.MonkeyPatch
) -> None:
    def fake_getaddrinfo(
        host: str, port: int | None, family: int | None = None
    ) -> list[tuple[object, ...]]:
        return [
            (None, None, None, None, ("8.8.8.8", 0)),
            (None, None, None, None, ("192.168.1.5", 0)),
        ]

    monkeypatch.setattr(socket, "getaddrinfo", fake_getaddrinfo)

    assert tray._candidate_lan_ips() == ["192.168.1.5"]


def test_candidate_lan_ips_falls_back_to_loopback_when_nothing_found(
    no_route: None, monkeypatch: pytest.MonkeyPatch
) -> None:
    def fake_getaddrinfo(
        host: str, port: int | None, family: int | None = None
    ) -> list[tuple[object, ...]]:
        raise socket.gaierror("no address")

    monkeypatch.setattr(socket, "getaddrinfo", fake_getaddrinfo)

    assert tray._candidate_lan_ips() == ["127.0.0.1"]
