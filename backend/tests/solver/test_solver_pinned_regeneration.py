from datetime import date

import pytest

from app.services.solver.errors import InvalidPinnedShiftsError
from app.services.solver.model import solve_roster
from app.services.solver.types import (
    EligibilityRule,
    PinnedShift,
    RosterSolveInput,
    SolverBuilding,
    SolverRoom,
    SolverStaff,
    Unavailability,
)

MONDAY = date(2026, 8, 3)


def test_pinned_shift_forces_staff_into_that_room() -> None:
    """A pinned assignment must survive regardless of what the solver would otherwise
    have preferred, and it still occupies the staff member's one-room-per-slot capacity
    so a second room in the same slot must go to someone else."""
    building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)
    room_1 = SolverRoom(id=1, building_id=1, tag_ids=frozenset())
    room_2 = SolverRoom(id=2, building_id=1, tag_ids=frozenset())
    staff_a = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset())
    staff_b = SolverStaff(id=2, role_ids=frozenset(), preferred_days=frozenset())

    result = solve_roster(
        RosterSolveInput(
            start_date=MONDAY,
            num_days=1,
            shift_length_minutes=240,
            travel_time_minutes=0,
            max_daily_minutes=720,
            buildings=[building],
            rooms=[room_1, room_2],
            staff=[staff_a, staff_b],
            pinned_shifts=[PinnedShift(staff_id=1, room_id=1, date=MONDAY, shift_index=0)],
        )
    )
    room_1_shift = next(s for s in result.shifts if s.room_id == 1)
    assert room_1_shift.staff_id == 1
    assert room_1_shift.pinned is True

    room_2_shift = next((s for s in result.shifts if s.room_id == 2), None)
    assert room_2_shift is not None
    assert room_2_shift.staff_id == 2  # staff_a is already committed to room 1


def test_regeneration_keeps_pinned_assignment_stable_across_solves() -> None:
    """Simulates a regeneration: solve once, pin the result, solve again with an added
    room — the original pinned assignment must be unchanged."""
    building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)
    room_1 = SolverRoom(id=1, building_id=1, tag_ids=frozenset())
    staff = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset())

    first = solve_roster(
        RosterSolveInput(
            start_date=MONDAY,
            num_days=1,
            shift_length_minutes=240,
            travel_time_minutes=0,
            max_daily_minutes=720,
            buildings=[building],
            rooms=[room_1],
            staff=[staff],
        )
    )
    assert len(first.shifts) == 1
    original = first.shifts[0]

    room_2 = SolverRoom(id=2, building_id=1, tag_ids=frozenset())
    second = solve_roster(
        RosterSolveInput(
            start_date=MONDAY,
            num_days=1,
            shift_length_minutes=240,
            travel_time_minutes=0,
            max_daily_minutes=720,
            buildings=[building],
            rooms=[room_1, room_2],
            staff=[staff],
            pinned_shifts=[
                PinnedShift(
                    staff_id=original.staff_id,
                    room_id=original.room_id,
                    date=original.date,
                    shift_index=original.shift_index,
                )
            ],
        )
    )
    carried_forward = next(s for s in second.shifts if s.room_id == room_1.id)
    assert carried_forward.staff_id == original.staff_id
    assert carried_forward.pinned is True
    # Room 2 stays unfilled: the only staff member is already committed to the pin, and
    # (as required) the one-room-per-person constraint still applies to pinned assignees.
    assert any(v.room_id == room_2.id for v in second.room_unfilled_violations)


def test_regeneration_rejects_pin_for_now_unavailable_staff() -> None:
    """A pin created while the staff member was available must not be silently forced
    through if they've since been marked unavailable (e.g. approved leave) — Unavailability
    is a hard constraint that pins may not bypass."""
    building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)
    room = SolverRoom(id=1, building_id=1, tag_ids=frozenset())
    staff = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset())

    with pytest.raises(InvalidPinnedShiftsError) as exc_info:
        solve_roster(
            RosterSolveInput(
                start_date=MONDAY,
                num_days=1,
                shift_length_minutes=240,
                travel_time_minutes=0,
                max_daily_minutes=720,
                buildings=[building],
                rooms=[room],
                staff=[staff],
                unavailabilities=[Unavailability(staff_id=1, start_date=MONDAY, end_date=MONDAY)],
                pinned_shifts=[PinnedShift(staff_id=1, room_id=1, date=MONDAY, shift_index=0)],
            )
        )
    assert exc_info.value.invalid_pins[0].reason == "staff member is unavailable"


def test_regeneration_rejects_pin_for_now_ineligible_staff() -> None:
    """A pin must not survive an eligibility rule added after it was created, for the same
    reason a fresh assignment couldn't be made there."""
    building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)
    room = SolverRoom(id=1, building_id=1, tag_ids=frozenset({10}))
    staff = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset())  # lacks role 99

    with pytest.raises(InvalidPinnedShiftsError) as exc_info:
        solve_roster(
            RosterSolveInput(
                start_date=MONDAY,
                num_days=1,
                shift_length_minutes=240,
                travel_time_minutes=0,
                max_daily_minutes=720,
                buildings=[building],
                rooms=[room],
                staff=[staff],
                eligibility_rules=[EligibilityRule(tag_id=10, role_id=99)],
                pinned_shifts=[PinnedShift(staff_id=1, room_id=1, date=MONDAY, shift_index=0)],
            )
        )
    reason = exc_info.value.invalid_pins[0].reason
    assert reason == "staff member is no longer eligible for this room"


def test_regeneration_rejects_pin_whose_room_slot_no_longer_exists() -> None:
    """Building hours can shrink between generations, removing the slot a prior pin
    referenced entirely — that must surface as a conflict, not a fabricated assignment."""
    building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)  # one 4h block
    room = SolverRoom(id=1, building_id=1, tag_ids=frozenset())
    staff = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset())

    with pytest.raises(InvalidPinnedShiftsError) as exc_info:
        solve_roster(
            RosterSolveInput(
                start_date=MONDAY,
                num_days=1,
                shift_length_minutes=240,
                travel_time_minutes=0,
                max_daily_minutes=720,
                buildings=[building],
                rooms=[room],
                staff=[staff],
                # shift_index 1 no longer exists now that the building only spans one block.
                pinned_shifts=[PinnedShift(staff_id=1, room_id=1, date=MONDAY, shift_index=1)],
            )
        )
    assert exc_info.value.invalid_pins[0].reason == "room-slot no longer exists"
