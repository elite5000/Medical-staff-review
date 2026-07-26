from typing import TYPE_CHECKING

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base
from app.models.associations import room_tags

if TYPE_CHECKING:
    from app.models.room import Room


class Tag(Base):
    __tablename__ = "tags"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String, unique=True)

    rooms: Mapped[list["Room"]] = relationship(secondary=room_tags, back_populates="tags")
