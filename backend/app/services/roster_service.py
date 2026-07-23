"""
Bridges the DB and the pure solver (app/services/solver): builds a RosterSolveInput from
current app state, persists a RosterSolveResult as new Roster/Shift/RosterViolation rows,
and handles the regenerate-with-pins and manual-edit-with-pin flows described in
CONTEXT.md's Roster entry.
"""

from datetime import UTC, date, datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.building import Building
from app.models.room import Room
from app.models.roster import Roster, RosterViolation, ViolationType
from app.models.rule import Rule, RuleType
from app.models.settings import AppSettings
from app.models.shift import Shift
from app.models.staff import Staff
from app.services.settings_service import get_settings
from app.services.solver.errors import (
    IndivisibleBuildingHoursError,
    InvalidPinnedShiftsError,
    RosterInfeasibleError,
)
from app.services.solver.model import solve_roster
from app.services.solver.timing import shifts_conflict
from app.services.solver.types import (
    EligibilityRule,
    MinimumCountRule,
    PinnedShift,
    RosterSolveInput,
    RosterSolveResult,
)
from app.services.solver.types import SolverBuilding as SBuilding
from app.services.solver.types import SolverRoom as SRoom
from app.services.solver.types import SolverStaff as SStaff
from app.services.solver.types import Unavailability as SUnavailability

DEFAULT_NUM_DAYS = 14


def _build_solver_input(
    db: Session,
    start_date: date,
    num_days: int,
    settings: AppSettings,
    pinned_shifts: list[PinnedShift],
) -> RosterSolveInput:
    buildings = [
        SBuilding(id=b.id, opening_minutes=b.opening_minutes, closing_minutes=b.closing_minutes)
        for b in db.scalars(select(Building))
    ]
    rooms = [
        SRoom(id=r.id, building_id=r.building_id, tag_ids=frozenset(t.id for t in r.tags))
        for r in db.scalars(select(Room))
    ]
    staff = [
        SStaff(
            id=s.id,
            role_ids=frozenset(r.id for r in s.roles),
            preferred_days=frozenset((pd.week, pd.day_of_week) for pd in s.preferred_days),
        )
        for s in db.scalars(select(Staff).where(Staff.active))
    ]
    rules = list(db.scalars(select(Rule)))
    minimum_count_rules = [
        MinimumCountRule(
            rule_id=r.id,
            role_id=r.role_id,
            building_id=r.building_id,
            tag_id=r.tag_id,
            minimum_count=r.minimum_count or 0,
        )
        for r in rules
        if r.rule_type is RuleType.MINIMUM_COUNT
    ]
    eligibility_rules = [
        EligibilityRule(tag_id=r.tag_id, role_id=r.role_id)
        for r in rules
        if r.rule_type is RuleType.ELIGIBILITY_RESTRICTION and r.tag_id is not None
    ]
    unavailabilities = [
        SUnavailability(staff_id=u.staff_id, start_date=u.start_date, end_date=u.end_date)
        for s in db.scalars(select(Staff))
        for u in s.unavailabilities
    ]

    return RosterSolveInput(
        start_date=start_date,
        num_days=num_days,
        shift_length_minutes=settings.shift_length_minutes,
        travel_time_minutes=settings.travel_time_minutes,
        max_daily_minutes=settings.max_daily_minutes,
        buildings=buildings,
        rooms=rooms,
        staff=staff,
        minimum_count_rules=minimum_count_rules,
        eligibility_rules=eligibility_rules,
        unavailabilities=unavailabilities,
        pinned_shifts=pinned_shifts,
    )


def _solve(solver_input: RosterSolveInput) -> RosterSolveResult:
    """Runs the pure solver and translates its hard-constraint-conflict exceptions into
    HTTPExceptions the API can return, instead of letting a 500 or a silently-wrong roster
    reach the caller."""
    try:
        return solve_roster(solver_input)
    except IndivisibleBuildingHoursError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except InvalidPinnedShiftsError as exc:
        detail = "; ".join(
            f"staff {p.staff_id} / room {p.room_id} / {p.date} slot {p.shift_index}: {p.reason}"
            for p in exc.invalid_pins
        )
        raise HTTPException(
            status_code=409, detail=f"Pinned shift(s) no longer valid: {detail}"
        ) from exc
    except RosterInfeasibleError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


def _persist_result(
    db: Session,
    result: RosterSolveResult,
    start_date: date,
    num_days: int,
    generated_from_roster_id: int | None,
) -> Roster:
    roster = Roster(
        start_date=start_date,
        end_date=start_date + timedelta(days=num_days - 1),
        generated_at=datetime.now(UTC).replace(tzinfo=None),
        generated_from_roster_id=generated_from_roster_id,
        has_violations=result.has_violations,
    )
    db.add(roster)
    db.flush()  # assigns roster.id without committing yet

    for solved in result.shifts:
        db.add(
            Shift(
                roster_id=roster.id,
                room_id=solved.room_id,
                staff_id=solved.staff_id,
                date=solved.date,
                shift_index=solved.shift_index,
                pinned=solved.pinned,
            )
        )
    for minimum_count_violation in result.minimum_count_violations:
        db.add(
            RosterViolation(
                roster_id=roster.id,
                violation_type=ViolationType.MINIMUM_COUNT_UNMET,
                rule_id=minimum_count_violation.rule_id,
                building_id=minimum_count_violation.building_id,
                tag_id=minimum_count_violation.tag_id,
                date=minimum_count_violation.date,
                shift_index=minimum_count_violation.shift_index,
                detail=f"Short by {minimum_count_violation.shortfall}",
            )
        )
    for room_unfilled_violation in result.room_unfilled_violations:
        db.add(
            RosterViolation(
                roster_id=roster.id,
                violation_type=ViolationType.ROOM_UNFILLED,
                room_id=room_unfilled_violation.room_id,
                date=room_unfilled_violation.date,
                shift_index=room_unfilled_violation.shift_index,
            )
        )

    db.commit()
    db.refresh(roster)
    return roster


def generate_roster(db: Session, start_date: date, num_days: int = DEFAULT_NUM_DAYS) -> Roster:
    """A fresh generation for a date range — no prior pinned assignments to carry forward."""
    settings = get_settings(db)
    solver_input = _build_solver_input(db, start_date, num_days, settings, pinned_shifts=[])
    result = _solve(solver_input)
    return _persist_result(db, result, start_date, num_days, generated_from_roster_id=None)


def regenerate_roster(db: Session, roster_id: int) -> Roster:
    """Re-solves the same date range, carrying the prior generation's pinned Shifts forward
    as fixed assignments — see CONTEXT.md's Roster entry."""
    previous = db.get(Roster, roster_id)
    if previous is None:
        raise HTTPException(status_code=404, detail="Roster not found")

    num_days = (previous.end_date - previous.start_date).days + 1
    pinned_shifts = [
        PinnedShift(
            staff_id=shift.staff_id,
            room_id=shift.room_id,
            date=shift.date,
            shift_index=shift.shift_index,
        )
        for shift in previous.shifts
        if shift.pinned
    ]

    settings = get_settings(db)
    solver_input = _build_solver_input(
        db, previous.start_date, num_days, settings, pinned_shifts=pinned_shifts
    )
    result = _solve(solver_input)
    return _persist_result(
        db, result, previous.start_date, num_days, generated_from_roster_id=roster_id
    )


def list_rosters(db: Session) -> list[Roster]:
    return list(db.scalars(select(Roster).order_by(Roster.generated_at.desc())))


def get_roster(db: Session, roster_id: int) -> Roster:
    roster = db.get(Roster, roster_id)
    if roster is None:
        raise HTTPException(status_code=404, detail="Roster not found")
    return roster


def _staff_eligible_for_room(db: Session, staff: Staff, room: Room) -> bool:
    tag_ids = {t.id for t in room.tags}
    if not tag_ids:
        return True
    restriction_rules = list(
        db.scalars(
            select(Rule).where(
                Rule.rule_type == RuleType.ELIGIBILITY_RESTRICTION, Rule.tag_id.in_(tag_ids)
            )
        )
    )
    if not restriction_rules:
        return True
    staff_role_ids = {r.id for r in staff.roles}
    return any(rule.role_id in staff_role_ids for rule in restriction_rules)


def set_shift_staff(db: Session, roster_id: int, shift_id: int, staff_id: int) -> Shift:
    """A manual edit: reassigns a Shift to a different staff member and pins it. Hard
    constraints are still enforced here — a human may override the solver's soft-goal
    choices freely, but never double-book a room/staff or break eligibility/Unavailability."""
    shift = db.get(Shift, shift_id)
    if shift is None or shift.roster_id != roster_id:
        raise HTTPException(status_code=404, detail="Shift not found")

    staff = db.get(Staff, staff_id)
    if staff is None:
        raise HTTPException(status_code=422, detail=f"Unknown staff_id: {staff_id}")

    if not staff.active:
        raise HTTPException(status_code=409, detail="Staff member is inactive")

    if not _staff_eligible_for_room(db, staff, shift.room):
        raise HTTPException(
            status_code=409, detail="Staff member is not eligible for this Room's Tags"
        )

    is_unavailable = any(u.start_date <= shift.date <= u.end_date for u in staff.unavailabilities)
    if is_unavailable:
        raise HTTPException(
            status_code=409, detail="Staff member is marked unavailable on this date"
        )

    # Building-relative shift_index alone doesn't tell us whether two shifts overlap in wall
    # clock time or leave enough Travel Time gap — that depends on each shift's Building's
    # opening hours, so every other shift the staff member has this day must be checked via
    # the same timing math the solver itself uses (see app/services/solver/timing.py).
    settings = get_settings(db)
    other_shifts_today = db.scalars(
        select(Shift).where(
            Shift.roster_id == roster_id,
            Shift.staff_id == staff_id,
            Shift.date == shift.date,
            Shift.id != shift.id,
        )
    )
    for other in other_shifts_today:
        if shifts_conflict(
            shift.room.building_id,
            shift.room.building.opening_minutes,
            shift.shift_index,
            other.room.building_id,
            other.room.building.opening_minutes,
            other.shift_index,
            settings.shift_length_minutes,
            settings.travel_time_minutes,
        ):
            raise HTTPException(
                status_code=409,
                detail=(
                    "Staff member already has a shift this day that overlaps or doesn't "
                    "leave enough Travel Time"
                ),
            )

    shift.staff_id = staff_id
    shift.pinned = True
    db.commit()
    db.refresh(shift)
    return shift
