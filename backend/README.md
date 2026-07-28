# Backend

FastAPI + SQLAlchemy + OR-Tools API. Serves the [Flutter app](../app) over HTTP: this
backend runs on one Windows PC on the admin's LAN, and the app is the client, on that same
PC and/or phones/tablets.

## Development

```
uv sync
uv run alembic upgrade head
uv run uvicorn app.main:app --port 8000
```

Runs on `http://localhost:8000`, using `dev.db` (a local SQLite file, gitignored). In this
mode there's no pairing-token check (see `app/config.py`'s `_default_pairing_token`) — that
only activates in the packaged desktop build.

### Tests / lint / types

```
uv run pytest
uv run ruff check .
uv run mypy app tests
```

## Packaging the desktop build

The backend also ships as a single Windows installer (tray icon, no terminal, starts
automatically at login) — see [`packaging/README.md`](packaging/README.md) for the build
steps and the OR-Tools/PyInstaller gotchas already solved there.
