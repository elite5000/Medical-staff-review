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
import socket
import sys
import threading
import tkinter as tk
from pathlib import Path
from tkinter import ttk

import qrcode
import uvicorn
from alembic import command
from alembic.config import Config
from PIL import Image, ImageDraw, ImageTk
from pystray import Icon, Menu, MenuItem

from app.config import settings
from app.paths import get_data_dir, is_frozen

PORT = 8765


def _backend_root() -> Path:
    """Directory containing alembic.ini + migrations/ in both dev and packaged layouts.

    In a packaged onedir build, bundled data lives under a `_internal/` subfolder next to
    the exe (not next to sys.executable itself) — sys._MEIPASS always points at the right
    place for both onedir and onefile builds, so use that instead of sys.executable.
    """
    if is_frozen():
        return Path(getattr(sys, "_MEIPASS"))  # noqa: B009
    return Path(__file__).resolve().parents[2]


def _lan_ip() -> str:
    """Best-effort LAN IPv4 via a UDP "connect" (no packets actually sent) — more reliable
    than hostname resolution on machines with multiple NICs/VPN adapters."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        ip = str(sock.getsockname()[0])
    except OSError:
        ip = "127.0.0.1"
    finally:
        sock.close()
    return ip


def _run_migrations() -> None:
    root = _backend_root()
    config = Config(str(root / "alembic.ini"))
    # env.py reads the DB URL from app.config.settings itself; script_location resolves
    # relative to alembic.ini via its own %(here)s, so nothing else needs overriding here.
    command.upgrade(config, "head")


def _serve() -> None:
    from app.main import app

    # 0.0.0.0, not the detected LAN IP: a socket bound to one specific address only accepts
    # traffic addressed to that address, not 127.0.0.1 — binding to just the LAN IP breaks
    # the Windows client's "localhost" default for the common case of running on the same PC
    # as the backend (this was tried and reverted). The pairing token, not the bind address,
    # is what actually keeps other devices out — see require_pairing_token in app/main.py.
    uvicorn.run(app, host="0.0.0.0", port=PORT, log_level="warning")  # noqa: S104


def _tray_icon_image() -> Image.Image:
    image = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((4, 4, 60, 60), fill="#2f6fed")
    return image


def _connection_payload() -> str:
    return json.dumps({"host": _lan_ip(), "port": PORT, "token": settings.pairing_token})


def _show_connection_window() -> None:
    """Opens a small window with a QR code encoding {host, port, token} for the Flutter
    app's "scan to connect" flow. Runs its own Tk mainloop in a dedicated thread each time
    it's invoked from the tray menu, so it never blocks the tray icon or the API server."""
    qr_image = qrcode.make(_connection_payload()).get_image().resize((320, 320))

    window = tk.Tk()
    window.title("Medical Staff Review — Connect a device")
    window.resizable(False, False)

    photo = ImageTk.PhotoImage(qr_image)
    image_label = ttk.Label(window, image=photo)
    image_label.image = photo  # type: ignore[attr-defined]  # keep a reference alive
    image_label.pack(padx=16, pady=(16, 8))

    ttk.Label(window, text=f"{_lan_ip()}:{PORT}", font=("Segoe UI", 12)).pack()

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


def main() -> None:
    _run_migrations()
    threading.Thread(target=_serve, daemon=True).start()

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
