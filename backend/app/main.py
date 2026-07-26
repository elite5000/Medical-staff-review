from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import buildings, roles, rooms, rosters, rules, staff, tags
from app.routers import settings as settings_router

app = FastAPI(title="Medical Staff Review API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
    """Dependency-free liveness check — used by Playwright's webServer polling in e2e runs."""
    return {"status": "ok"}
