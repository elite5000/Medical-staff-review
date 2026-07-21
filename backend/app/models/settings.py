from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class AppSettings(Base):
    """Singleton row (id is always 1) holding the app-wide roster settings."""

    __tablename__ = "settings"

    id: Mapped[int] = mapped_column(primary_key=True, default=1)
    shift_length_minutes: Mapped[int] = mapped_column(default=240)
    travel_time_minutes: Mapped[int] = mapped_column(default=30)
    max_daily_minutes: Mapped[int] = mapped_column(default=720)
