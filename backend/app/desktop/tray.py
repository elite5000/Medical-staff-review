"""Desktop entry point for the packaged Windows build.

Runs Alembic migrations, then the FastAPI app (via uvicorn) in a background thread, behind
a system tray icon — so a non-technical admin never touches a terminal. This module is the
executable PyInstaller packages (see backend/packaging/), not something imported by the
FastAPI app itself, and it isn't covered by the pytest suite: it's a thin composition of
already-tested pieces (app.main:app, the Alembic migrations, uvicorn) plus OS-level tray/
window code that only makes sense to verify by running the packaged .exe (see the plan's
Verification section).
"""

from __future__ import annotations

import http.client
import json
import ssl
import sys
import threading
import time
import tkinter as tk
from datetime import UTC, datetime, timedelta
from pathlib import Path
from tkinter import messagebox

import uvicorn
from alembic import command
from alembic.config import Config
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID
from PIL import Image, ImageDraw
from pystray import Icon, Menu, MenuItem

from app.config import settings
from app.discovery import BACKEND_PORT, start_discovery_responder
from app.paths import get_data_dir, is_frozen

PORT = BACKEND_PORT
_CERT_LOCK = threading.Lock()


def _backend_root() -> Path:
    """Directory containing alembic.ini + migrations/ in both dev and packaged layouts.

    In a packaged onedir build, bundled data lives under a `_internal/` subfolder next to
    the exe (not next to sys.executable itself) — sys._MEIPASS always points at the right
    place for both onedir and onefile builds, so use that instead of sys.executable.
    """
    if is_frozen():
        return Path(getattr(sys, "_MEIPASS"))  # noqa: B009
    return Path(__file__).resolve().parents[2]


def _run_migrations() -> None:
    root = _backend_root()
    config = Config(str(root / "alembic.ini"))
    # env.py reads the DB URL from app.config.settings itself; script_location resolves
    # relative to alembic.ini via its own %(here)s, so nothing else needs overriding here.
    command.upgrade(config, "head")


def _ensure_certificate() -> tuple[Path, Path]:
    """Generates a self-signed cert + key on first run, persisted next to the DB/pairing
    token — same idempotent "generate once, reuse forever" pattern as
    app/config.py's _default_pairing_token. Encrypts the pairing token in transit; the
    Flutter client pins the cert's fingerprint (handed out by app/discovery.py) rather than relying
    on a CA, since there's no real hostname to issue a CA-signed cert for here.
    """
    data_dir = get_data_dir()
    cert_path = data_dir / "cert.pem"
    key_path = data_dir / "key.pem"
    with _CERT_LOCK:
        if cert_path.exists() and key_path.exists():
            return cert_path, key_path

        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Medical Staff Review")])
        now = datetime.now(UTC)
        cert = (
            x509.CertificateBuilder()
            .subject_name(name)
            .issuer_name(name)
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(now)
            .not_valid_after(now + timedelta(days=3650))
            .sign(key, hashes.SHA256())
        )

        tmp_key_path = key_path.with_name(f"{key_path.name}.tmp")
        tmp_cert_path = cert_path.with_name(f"{cert_path.name}.tmp")
        tmp_key_path.write_bytes(
            key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption(),
            )
        )
        tmp_cert_path.write_bytes(cert.public_bytes(serialization.Encoding.PEM))
        tmp_key_path.replace(key_path)
        tmp_cert_path.replace(cert_path)
        return cert_path, key_path


def _cert_fingerprint(cert_path: Path) -> str:
    cert = x509.load_pem_x509_certificate(cert_path.read_bytes())
    return cert.fingerprint(hashes.SHA256()).hex()


def _serve() -> None:
    from app.main import app

    cert_path, key_path = _ensure_certificate()
    # 0.0.0.0, not the detected LAN IP: a socket bound to one specific address only accepts
    # traffic addressed to that address, not 127.0.0.1 — binding to just the LAN IP breaks
    # the Windows client's "localhost" default for the common case of running on the same PC
    # as the backend (this was tried and reverted). The pairing token, not the bind address,
    # is what actually keeps other devices out — see require_pairing_token in app/main.py.
    uvicorn.run(
        app,
        host="0.0.0.0",  # noqa: S104
        port=PORT,
        log_level="warning",
        ssl_certfile=str(cert_path),
        ssl_keyfile=str(key_path),
    )


def _tray_icon_image() -> Image.Image:
    image = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((4, 4, 60, 60), fill="#2f6fed")
    return image


def _open_data_folder() -> None:
    import os

    os.startfile(get_data_dir())  # noqa: S606  (Windows-only build; this is explorer.exe)


def _wait_for_server_ready(
    server_thread: threading.Thread,
    expected_fingerprint: str,
    cert_path: Path,
    timeout_seconds: float = 8.0,
) -> bool:
    """Waits for this app's HTTPS /health endpoint with the expected certificate."""

    deadline = time.monotonic() + timeout_seconds
    ssl_context = ssl.create_default_context()
    ssl_context.check_hostname = False
    ssl_context.verify_mode = ssl.CERT_REQUIRED
    ssl_context.load_verify_locations(cafile=str(cert_path))

    while time.monotonic() < deadline:
        if not server_thread.is_alive():
            return False
        try:
            conn = http.client.HTTPSConnection(
                "127.0.0.1",
                PORT,
                timeout=0.5,
                context=ssl_context,
            )
            conn.request("GET", "/health")
            response = conn.getresponse()
            cert = conn.sock.getpeercert(binary_form=True)
            body = response.read().decode("utf-8")
            conn.close()

            if response.status != 200:
                time.sleep(0.1)
                continue

            if cert is None:
                time.sleep(0.1)
                continue

            digest = hashes.Hash(hashes.SHA256())
            digest.update(cert)
            if digest.finalize().hex() != expected_fingerprint:
                time.sleep(0.1)
                continue
            payload = json.loads(body)
            if payload.get("status") == "ok":
                return True
        except (
            OSError,
            ssl.SSLError,
            http.client.HTTPException,
            json.JSONDecodeError,
            ValueError,
        ):
            pass
        if not server_thread.is_alive():
            return False
        time.sleep(0.1)
    return False


def _show_startup_error(message: str) -> None:
    root = tk.Tk()
    root.withdraw()
    messagebox.showerror(
        "Medical Staff Review startup error",
        f"The local backend could not start.\n\n{message}\n\n"
        f"Fix the issue and relaunch the app. Common causes include port {PORT} already in use "
        "or invalid TLS certificate files in the data folder.",
    )
    root.destroy()


def _redirect_missing_stdio() -> None:
    """Points sys.stdout/sys.stderr at a log file when the windowed build leaves them None.

    A console=False PyInstaller exe starts with no stdio streams, and uvicorn's default
    logging config calls sys.stdout.isatty() while building its formatter — which fails as
    "Unable to configure formatter 'default'". Sending both streams to backend.log in the
    data folder fixes that and keeps server output somewhere an admin can find it.
    """
    if sys.stdout is not None and sys.stderr is not None:
        return
    log_file = open(get_data_dir() / "backend.log", "a", encoding="utf-8", buffering=1)  # noqa: SIM115
    if sys.stdout is None:
        sys.stdout = log_file
    if sys.stderr is None:
        sys.stderr = log_file


def main() -> None:
    _redirect_missing_stdio()
    try:
        _run_migrations()
        cert_path, _ = _ensure_certificate()
        expected_fingerprint = _cert_fingerprint(cert_path)
    except Exception as exc:  # pragma: no cover - startup path is integration-only
        _show_startup_error(f"Database startup failed: {exc}")
        return

    startup_errors: list[str] = []

    def serve_with_error_capture() -> None:
        try:
            _serve()
        except Exception as exc:  # pragma: no cover - startup path is integration-only
            startup_errors.append(str(exc))

    server_thread = threading.Thread(target=serve_with_error_capture, daemon=True)
    server_thread.start()
    if not _wait_for_server_ready(server_thread, expected_fingerprint, cert_path):
        detail = startup_errors[0] if startup_errors else "The server did not become reachable."
        _show_startup_error(detail)
        return

    try:
        start_discovery_responder(settings.pairing_token, expected_fingerprint)
    except OSError as exc:  # pragma: no cover - startup path is integration-only
        _show_startup_error(f"Could not listen for devices on UDP port {PORT}: {exc}")
        return

    def open_data_folder(icon: Icon, item: MenuItem) -> None:
        _open_data_folder()

    def quit_app(icon: Icon, item: MenuItem) -> None:
        icon.stop()

    icon = Icon(
        "MedicalStaffReview",
        _tray_icon_image(),
        "Medical Staff Review",
        menu=Menu(
            MenuItem("Open data folder", open_data_folder),
            MenuItem("Quit", quit_app),
        ),
    )
    icon.run()


if __name__ == "__main__":
    main()
