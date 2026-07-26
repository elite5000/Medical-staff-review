from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.schemas.settings import SettingsRead, SettingsUpdate
from app.services import settings_service

router = APIRouter(prefix="/settings", tags=["settings"])


@router.get("", response_model=SettingsRead)
def get_settings(db: Session = Depends(get_db)) -> SettingsRead:
    return SettingsRead.model_validate(settings_service.get_settings(db))


@router.patch("", response_model=SettingsRead)
def update_settings(data: SettingsUpdate, db: Session = Depends(get_db)) -> SettingsRead:
    return SettingsRead.model_validate(settings_service.update_settings(db, data))
