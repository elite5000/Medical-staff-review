from collections.abc import Awaitable, Callable

from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse

from app.config import settings
from app.routers import buildings, roles, rooms, rosters, rules, staff, tags
from app.routers import settings as settings_router

app = FastAPI(title="Medical Staff Review API")


@app.middleware("http")
async def require_pairing_token(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
) -> Response:
    """Gates every request but /health behind the packaged app's per-install pairing token.

    No-op in dev/test, where settings.pairing_token is None (see app/config.py's
    _default_pairing_token) — only the packaged desktop build generates and enforces one, so
    that other devices on the same LAN can't use the API without first pairing via the tray
    app's QR code.
    """
    if settings.pairing_token and request.url.path != "/health":
        if request.headers.get("authorization") != f"Bearer {settings.pairing_token}":
            return JSONResponse({"detail": "Invalid or missing pairing token"}, status_code=401)
    return await call_next(request)


app.include_router(buildings.router)
app.include_router(rooms.router)
app.include_router(tags.router)
app.include_router(roles.router)
app.include_router(staff.router)
app.include_router(rules.router)
app.include_router(settings_router.router)
app.include_router(rosters.router)


@app.get("/health")
def health() -> dict[str, str]:
    """Dependency-free liveness check, exempt from the pairing-token gate above."""
    return {"status": "ok"}
