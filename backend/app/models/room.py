from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base
from app.models.associations import room_tags

if TYPE_CHECKING:
    from app.models.building import Building
    from app.models.tag import Tag


class Room(Base):
    __tablename__ = "rooms"

    id: Mapped[int] = mapped_column(primary_key=True)
    building_id: Mapped[int] = mapped_column(ForeignKey("buildings.id"))
    name: Mapped[str] = mapped_column(String)

    building: Mapped["Building"] = relationship(back_populates="rooms")
    tags: Mapped[list["Tag"]] = relationship(secondary=room_tags, back_populates="rooms")
