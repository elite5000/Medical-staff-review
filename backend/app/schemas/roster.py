from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.roster import ViolationType


class RosterGenerateRequest(BaseModel):
    start_date: date
    # A 0 or negative value would let _persist_result compute an end_date before start_date.
    # The upper bound of 14 matches the fortnight this app is scoped to (see CONTEXT.md's
    # Roster entry) and the solver's fixed objective weights, which are only guaranteed to
    # preserve strict soft-goal priority for len(dates) <= 14 (see the comment above
    # _WEIGHT_MINIMUM_COUNT in app/services/solver/model.py) — a much longer roster could
    # accumulate enough lower-tier terms to outweigh a higher tier.
    num_days: int = Field(default=14, ge=1, le=14)


class ShiftRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    room_id: int
    staff_id: int
    date: date
    shift_index: int
    pinned: bool


class RosterViolationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    violation_type: ViolationType
    rule_id: int | None
    building_id: int | None
    tag_id: int | None
    room_id: int | None
    date: date
    shift_index: int
    detail: str | None


class RosterRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    start_date: date
    end_date: date
    generated_at: datetime
    generated_from_roster_id: int | None
    has_violations: bool


class RosterDetailRead(RosterRead):
    shifts: list[ShiftRead]
    violations: list[RosterViolationRead]


class ShiftUpdateRequest(BaseModel):
    staff_id: int
