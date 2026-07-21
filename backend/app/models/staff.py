from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base
from app.models.associations import staff_roles

if TYPE_CHECKING:
    from app.models.role import Role


class Staff(Base):
    __tablename__ = "staff"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String)
    active: Mapped[bool] = mapped_column(Boolean, default=True)

    roles: Mapped[list["Role"]] = relationship(secondary=staff_roles, back_populates="staff")
    preferred_days: Mapped[list["PreferredDay"]] = relationship(
        back_populates="staff", cascade="all, delete-orphan"
    )
    unavailabilities: Mapped[list["Unavailability"]] = relationship(
        back_populates="staff", cascade="all, delete-orphan"
    )


class PreferredDay(Base):
    """A staff member's standing, recurring day-of-week preference (soft goal for the solver)."""

    __tablename__ = "staff_preferred_days"
    __table_args__ = (UniqueConstraint("staff_id", "day_of_week"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    staff_id: Mapped[int] = mapped_column(ForeignKey("staff.id"))
    day_of_week: Mapped[int]  # 0 = Monday ... 6 = Sunday

    staff: Mapped["Staff"] = relationship(back_populates="preferred_days")


class Unavailability(Base):
    """A hard, date-specific block (e.g. leave) the solver must never assign a shift within."""

    __tablename__ = "unavailabilities"

    id: Mapped[int] = mapped_column(primary_key=True)
    staff_id: Mapped[int] = mapped_column(ForeignKey("staff.id"))
    start_date: Mapped[date]
    end_date: Mapped[date]
    reason: Mapped[str | None] = mapped_column(String, default=None)

    staff: Mapped["Staff"] = relationship(back_populates="unavailabilities")
