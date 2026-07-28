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

import json
import ipaddress
import socket
import sys
import threading
import time
import tkinter as tk
from datetime import UTC, datetime, timedelta
from pathlib import Path
from tkinter import messagebox, ttk

import qrcode
import uvicorn
from alembic import command
from alembic.config import Config
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID
from PIL import Image, ImageDraw, ImageTk
from pystray import Icon, Menu, MenuItem

from app.config import settings
from app.paths import get_data_dir, is_frozen

PORT = 8765
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


def _candidate_lan_ips() -> list[str]:
    """Returns non-loopback IPv4 candidates for client devices to reach this host.

    Prioritizes private RFC1918 addresses (typical LAN adapters), while still keeping a
    non-private fallback when that's all the host has.
    """

    def _append_unique(items: list[str], value: str) -> None:
        if value not in items:
            items.append(value)

    candidates: list[str] = []

    # Route-based hint (can be wrong with full-tunnel VPN, but useful as one signal).
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        route_ip = str(sock.getsockname()[0])
        if route_ip != "127.0.0.1":
            _append_unique(candidates, route_ip)
    except OSError:
        pass
    finally:
        sock.close()

    for host in (socket.gethostname(), socket.getfqdn()):
        try:
            for entry in socket.getaddrinfo(host, None, family=socket.AF_INET):
                ip = str(entry[4][0])
                if ip != "127.0.0.1":
                    _append_unique(candidates, ip)
        except OSError:
            continue

    private = [ip for ip in candidates if ipaddress.ip_address(ip).is_private]
    if private:
        return private
    if candidates:
        return candidates
    return ["127.0.0.1"]


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
    Flutter client pins the cert's fingerprint (see _connection_payload) rather than relying
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


def _connection_payload(host: str) -> str:
    cert_path, _ = _ensure_certificate()
    return json.dumps(
        {
            "host": host,
            "port": PORT,
            "token": settings.pairing_token,
            "cert_fingerprint": _cert_fingerprint(cert_path),
        }
    )


def _show_connection_window() -> None:
    """Opens a small window with a QR code encoding {host, port, token} for the Flutter
    app's "scan to connect" flow. Runs its own Tk mainloop in a dedicated thread each time
    it's invoked from the tray menu, so it never blocks the tray icon or the API server."""
    candidate_ips = _candidate_lan_ips()

    window = tk.Tk()
    window.title("Medical Staff Review — Connect a device")
    window.resizable(False, False)

    selected_host = tk.StringVar(value=candidate_ips[0])
    address_var = tk.StringVar(value=f"{selected_host.get()}:{PORT}")

    image_label = ttk.Label(window)
    image_label.pack(padx=16, pady=(16, 8))

    def update_qr(host: str) -> None:
        qr_image = qrcode.make(_connection_payload(host)).get_image().resize((320, 320))
        photo = ImageTk.PhotoImage(qr_image)
        image_label.configure(image=photo)
        image_label.image = photo  # type: ignore[attr-defined]  # keep a reference alive
        address_var.set(f"{host}:{PORT}")

    update_qr(selected_host.get())

    if len(candidate_ips) > 1:
        ttk.Label(window, text="Host / IP for other devices").pack(pady=(0, 4))
        host_picker = ttk.Combobox(
            window,
            values=candidate_ips,
            textvariable=selected_host,
            state="readonly",
            width=28,
        )
        host_picker.pack(padx=16, pady=(0, 8))
        host_picker.bind(
            "<<ComboboxSelected>>",
            lambda _event: update_qr(selected_host.get()),
        )

    ttk.Label(window, textvariable=address_var, font=("Segoe UI", 12)).pack()

    # QR scanning is Android-only (see connect_screen.dart's _isMobile) — Windows and macOS
    # clients must type host/port/token by hand, so the token needs to be shown here too,
    # not just embedded in the QR image. A read-only Entry (rather than a Label) lets the
    # admin select and copy it directly, backed up by an explicit copy-to-clipboard button.
    token = settings.pairing_token or ""
    token_var = tk.StringVar(value=token)
    token_entry = ttk.Entry(
        window, textvariable=token_var, state="readonly", width=36, justify="center"
    )
    token_entry.pack(padx=16, pady=(8, 4))

    def copy_token() -> None:
        window.clipboard_clear()
        window.clipboard_append(token)

    ttk.Button(window, text="Copy token", command=copy_token).pack(pady=(0, 16))
    window.mainloop()


def _open_data_folder() -> None:
    import os

    os.startfile(get_data_dir())  # noqa: S606  (Windows-only build; this is explorer.exe)


def _wait_for_server_ready(server_thread: threading.Thread, timeout_seconds: float = 8.0) -> bool:
    """Waits for the local API socket to become reachable or for startup failure."""

    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        if not server_thread.is_alive():
            return False
        probe = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            probe.settimeout(0.25)
            if probe.connect_ex(("127.0.0.1", PORT)) == 0:
                return True
        finally:
            probe.close()
        time.sleep(0.1)
    return server_thread.is_alive()


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


def main() -> None:
    _run_migrations()
    _ensure_certificate()

    startup_errors: list[str] = []

    def serve_with_error_capture() -> None:
        try:
            _serve()
        except Exception as exc:  # pragma: no cover - startup path is integration-only
            startup_errors.append(str(exc))

    server_thread = threading.Thread(target=serve_with_error_capture, daemon=True)
    server_thread.start()
    if not _wait_for_server_ready(server_thread):
        detail = startup_errors[0] if startup_errors else "The server did not become reachable."
        _show_startup_error(detail)
        return

    def show_connection_window(icon: Icon, item: MenuItem) -> None:
        threading.Thread(target=_show_connection_window, daemon=True).start()

    def open_data_folder(icon: Icon, item: MenuItem) -> None:
        _open_data_folder()

    def quit_app(icon: Icon, item: MenuItem) -> None:
        icon.stop()

    icon = Icon(
        "MedicalStaffReview",
        _tray_icon_image(),
        "Medical Staff Review",
        menu=Menu(
            MenuItem("Show connection QR", show_connection_window),
            MenuItem("Open data folder", open_data_folder),
            MenuItem("Quit", quit_app),
        ),
    )
    icon.run()


if __name__ == "__main__":
    main()
