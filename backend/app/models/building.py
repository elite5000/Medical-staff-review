from typing import TYPE_CHECKING

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base

if TYPE_CHECKING:
    from app.models.room import Room


class Building(Base):
    __tablename__ = "buildings"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String, unique=True)
    # Opening hours as minutes-from-midnight, same window every day of the roster period.
    opening_minutes: Mapped[int]
    closing_minutes: Mapped[int]

    rooms: Mapped[list["Room"]] = relationship(back_populates="building")
