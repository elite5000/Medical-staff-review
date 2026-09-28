"""Dev entry point: `uv run python -m app.dev_server`.

Runs the API over plain HTTP on the fixed BACKEND_PORT plus the discovery responder, so the
Flutter app finds a dev backend exactly the way it finds the packaged one (no pairing token,
no TLS — see app/config.py's _default_pairing_token).
"""

import uvicorn

from app.discovery import BACKEND_PORT, start_discovery_responder


def main() -> None:
    start_discovery_responder(token=None, cert_fingerprint=None)
    uvicorn.run("app.main:app", host="0.0.0.0", port=BACKEND_PORT)  # noqa: S104


if __name__ == "__main__":
    main()
