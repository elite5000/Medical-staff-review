from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base

if TYPE_CHECKING:
    from app.models.room import Room
    from app.models.roster import Roster
    from app.models.staff import Staff


class Shift(Base):
    """
    An actual staff-to-room assignment for one shift block. Only real assignments are
    stored here (staff_id is NOT NULL) — unfilled room-hours are computed at generation
    time and recorded as RosterViolation rows instead of sparse null-staff rows.
    """

    __tablename__ = "shifts"
    __table_args__ = (
        UniqueConstraint("roster_id", "room_id", "date", "shift_index"),
        UniqueConstraint("roster_id", "staff_id", "date", "shift_index"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    roster_id: Mapped[int] = mapped_column(ForeignKey("rosters.id"))
    room_id: Mapped[int] = mapped_column(ForeignKey("rooms.id"))
    staff_id: Mapped[int] = mapped_column(ForeignKey("staff.id"))
    date: Mapped[date]
    shift_index: Mapped[int]
    pinned: Mapped[bool] = mapped_column(default=False)

    roster: Mapped["Roster"] = relationship(back_populates="shifts")
    room: Mapped["Room"] = relationship()
    staff: Mapped["Staff"] = relationship()
