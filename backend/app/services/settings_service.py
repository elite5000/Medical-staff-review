from sqlalchemy.orm import Session

from app.models.settings import AppSettings
from app.schemas.settings import SettingsUpdate

SINGLETON_ID = 1


def get_settings(db: Session) -> AppSettings:
    # Lazily create the singleton row on first access rather than seeding it via migration,
    # so the model's column defaults (see app/models/settings.py) stay the single source of
    # truth for "what a fresh install starts with".
    settings = db.get(AppSettings, SINGLETON_ID)
    if settings is None:
        settings = AppSettings(id=SINGLETON_ID)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings


def update_settings(db: Session, data: SettingsUpdate) -> AppSettings:
    settings = get_settings(db)
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(settings, field, value)
    db.commit()
    db.refresh(settings)
    return settings
