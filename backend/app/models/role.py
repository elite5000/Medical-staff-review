from typing import TYPE_CHECKING

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base
from app.models.associations import staff_roles

if TYPE_CHECKING:
    from app.models.staff import Staff


class Role(Base):
    __tablename__ = "roles"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String, unique=True)

    staff: Mapped[list["Staff"]] = relationship(secondary=staff_roles, back_populates="roles")
