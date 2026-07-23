"""
Exceptions the solver raises for genuine hard-constraint conflicts, as opposed to the
soft-goal shortfalls ADR 0001 says must never block generation. Kept dependency-free (no
FastAPI) like the rest of the solver package; app/services/roster_service.py translates
these into HTTPExceptions.
"""

from dataclasses import dataclass
from datetime import date


@dataclass(frozen=True)
class InvalidPinnedShift:
    """A previously pinned Shift that no longer satisfies a hard constraint — e.g. the
    staff member became unavailable/inactive, lost eligibility, or the room-slot no longer
    exists — because settings, Building hours, or Staff state changed since it was pinned."""

    staff_id: int
    room_id: int
    date: date
    shift_index: int
    reason: str


class InvalidPinnedShiftsError(Exception):
    """Raised instead of silently forcing pinned shifts that would bypass Unavailability,
    eligibility, or a since-removed room-slot."""

    def __init__(self, invalid_pins: list[InvalidPinnedShift]):
        self.invalid_pins = invalid_pins
        super().__init__(f"{len(invalid_pins)} pinned shift(s) no longer satisfy hard constraints")


class RosterInfeasibleError(Exception):
    """Raised when the CP-SAT solver cannot find any assignment satisfying every hard
    constraint (e.g. remaining valid pins conflict with each other or with Unavailability/
    Max Daily Hours/Travel Time)."""


class IndivisibleBuildingHoursError(Exception):
    """Raised when a Building's open interval is not an exact multiple of the current Shift
    Length, which would otherwise silently drop the remainder from the schedulable day."""

    def __init__(self, building_ids: list[int]):
        self.building_ids = building_ids
        super().__init__(
            f"Building(s) {building_ids} open interval does not divide evenly into shifts"
        )
