import enum
from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import Enum, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base

if TYPE_CHECKING:
    from app.models.shift import Shift


class ViolationType(enum.StrEnum):
    MINIMUM_COUNT_UNMET = "minimum_count_unmet"
    ROOM_UNFILLED = "room_unfilled"


class Roster(Base):
    """
    A generated 14-day schedule tied to a date range. Regeneration always inserts a new
    Roster row (never mutates an old one) so every generation is retained permanently for
    review/audit — see CONTEXT.md's Roster entry.
    """

    __tablename__ = "rosters"

    id: Mapped[int] = mapped_column(primary_key=True)
    start_date: Mapped[date]
    end_date: Mapped[date]
    generated_at: Mapped[datetime]
    generated_from_roster_id: Mapped[int | None] = mapped_column(
        ForeignKey("rosters.id"), default=None
    )
    has_violations: Mapped[bool] = mapped_column(default=False)

    shifts: Mapped[list["Shift"]] = relationship(back_populates="roster")
    violations: Mapped[list["RosterViolation"]] = relationship(back_populates="roster")


class RosterViolation(Base):
    """
    A flagged soft-goal shortfall on a specific Roster (see ADR 0001): a minimum-count rule
    that couldn't be satisfied, or a room-hour that went unfilled. Never blocks generation —
    surfaced to the user for review instead.
    """

    __tablename__ = "roster_violations"

    id: Mapped[int] = mapped_column(primary_key=True)
    roster_id: Mapped[int] = mapped_column(ForeignKey("rosters.id"))
    # values_callable: store the enum's value ("minimum_count_unmet"), not its member name
    # ("MINIMUM_COUNT_UNMET") — see the identical fix and rationale on Rule.rule_type.
    violation_type: Mapped[ViolationType] = mapped_column(
        Enum(ViolationType, values_callable=lambda enum_cls: [member.value for member in enum_cls])
    )
    rule_id: Mapped[int | None] = mapped_column(ForeignKey("rules.id"), default=None)
    building_id: Mapped[int | None] = mapped_column(ForeignKey("buildings.id"), default=None)
    tag_id: Mapped[int | None] = mapped_column(ForeignKey("tags.id"), default=None)
    room_id: Mapped[int | None] = mapped_column(ForeignKey("rooms.id"), default=None)
    date: Mapped[date]
    shift_index: Mapped[int]
    detail: Mapped[str | None] = mapped_column(default=None)

    roster: Mapped["Roster"] = relationship(back_populates="violations")
