"""
Pure data types for the roster solver — no FastAPI/SQLAlchemy dependency, so the solver
(app/services/solver/model.py) can be unit-tested with small constructed scenarios instead
of a real database. app/services/roster_service.py is the only caller, translating ORM rows
into these types and results back into Shift/RosterViolation rows.
"""

from dataclasses import dataclass, field
from datetime import date


@dataclass(frozen=True)
class SolverBuilding:
    id: int
    opening_minutes: int
    closing_minutes: int


@dataclass(frozen=True)
class SolverRoom:
    id: int
    building_id: int
    tag_ids: frozenset[int]


@dataclass(frozen=True)
class SolverStaff:
    id: int
    role_ids: frozenset[int]
    # (week, day_of_week): week 0 = week 1, week 1 = week 2 of the fortnight;
    # day_of_week 0 = Monday ... 6 = Sunday.
    preferred_days: frozenset[tuple[int, int]]


@dataclass(frozen=True)
class MinimumCountRule:
    rule_id: int
    role_id: int
    building_id: int | None
    tag_id: int | None
    minimum_count: int


@dataclass(frozen=True)
class EligibilityRule:
    tag_id: int
    role_id: int


@dataclass(frozen=True)
class Unavailability:
    staff_id: int
    start_date: date
    end_date: date


@dataclass(frozen=True)
class PinnedShift:
    """An existing Shift, carried forward as a fixed assignment during regeneration."""

    staff_id: int
    room_id: int
    date: date
    shift_index: int


@dataclass(frozen=True)
class RosterSolveInput:
    start_date: date
    num_days: int
    shift_length_minutes: int
    travel_time_minutes: int
    max_daily_minutes: int
    buildings: list[SolverBuilding]
    rooms: list[SolverRoom]
    staff: list[SolverStaff]
    minimum_count_rules: list[MinimumCountRule] = field(default_factory=list)
    eligibility_rules: list[EligibilityRule] = field(default_factory=list)
    unavailabilities: list[Unavailability] = field(default_factory=list)
    pinned_shifts: list[PinnedShift] = field(default_factory=list)


@dataclass(frozen=True)
class SolvedShift:
    staff_id: int
    room_id: int
    date: date
    shift_index: int
    pinned: bool


@dataclass(frozen=True)
class MinimumCountViolation:
    rule_id: int
    building_id: int | None
    tag_id: int | None
    date: date
    shift_index: int
    shortfall: int


@dataclass(frozen=True)
class RoomUnfilledViolation:
    room_id: int
    date: date
    shift_index: int


@dataclass(frozen=True)
class RosterSolveResult:
    shifts: list[SolvedShift]
    minimum_count_violations: list[MinimumCountViolation]
    room_unfilled_violations: list[RoomUnfilledViolation]

    @property
    def has_violations(self) -> bool:
        return bool(self.minimum_count_violations or self.room_unfilled_violations)
