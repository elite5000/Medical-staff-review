from datetime import date

import pytest

from app.services.solver.errors import IndivisibleBuildingHoursError, RosterInfeasibleError
from app.services.solver.model import solve_roster
from app.services.solver.types import (
    EligibilityRule,
    PinnedShift,
    RosterSolveInput,
    RosterSolveResult,
    SolvedShift,
    SolverBuilding,
    SolverRoom,
    SolverStaff,
    Unavailability,
)

START = date(2026, 8, 3)  # a Monday


def _shifts_for(result: RosterSolveResult, staff_id: int) -> list[SolvedShift]:
    return [s for s in result.shifts if s.staff_id == staff_id]


def test_never_double_books_a_room() -> None:
    """One room can only ever hold one staff member per shift block."""
    building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)  # one 4h block
    room = SolverRoom(id=1, building_id=1, tag_ids=frozenset())
    staff = [SolverStaff(id=i, role_ids=frozenset(), preferred_days=frozenset()) for i in (1, 2)]

    result = solve_roster(
        RosterSolveInput(
            start_date=START,
            num_days=1,
            shift_length_minutes=240,
            travel_time_minutes=0,
            max_daily_minutes=720,
            buildings=[building],
            rooms=[room],
            staff=staff,
        )
    )
    assignments_for_room = [s for s in result.shifts if s.room_id == 1 and s.date == START]
    assert len(assignments_for_room) <= 1


def test_eligibility_restriction_excludes_unqualified_staff() -> None:
    """Only staff holding a required Role may be assigned to a Tag-restricted room."""
    building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)
    room = SolverRoom(id=1, building_id=1, tag_ids=frozenset({10}))
    qualified = SolverStaff(id=1, role_ids=frozenset({99}), preferred_days=frozenset())
    unqualified = SolverStaff(id=2, role_ids=frozenset(), preferred_days=frozenset())

    result = solve_roster(
        RosterSolveInput(
            start_date=START,
            num_days=1,
            shift_length_minutes=240,
            travel_time_minutes=0,
            max_daily_minutes=720,
            buildings=[building],
            rooms=[room],
            staff=[qualified, unqualified],
            eligibility_rules=[EligibilityRule(tag_id=10, role_id=99)],
        )
    )
    staff_assigned = {s.staff_id for s in result.shifts}
    assert staff_assigned <= {1}


def test_unavailability_blocks_assignment_on_that_date() -> None:
    building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)
    room = SolverRoom(id=1, building_id=1, tag_ids=frozenset())
    staff = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset())

    result = solve_roster(
        RosterSolveInput(
            start_date=START,
            num_days=1,
            shift_length_minutes=240,
            travel_time_minutes=0,
            max_daily_minutes=720,
            buildings=[building],
            rooms=[room],
            staff=[staff],
            unavailabilities=[Unavailability(staff_id=1, start_date=START, end_date=START)],
        )
    )
    assert result.shifts == []


def test_max_daily_hours_caps_shift_count() -> None:
    """3 rooms x 4h blocks = 12h available, but an 8h cap should allow at most 2 blocks."""
    building = SolverBuilding(id=1, opening_minutes=0, closing_minutes=12 * 60)
    rooms = [SolverRoom(id=i, building_id=1, tag_ids=frozenset()) for i in (1, 2, 3)]
    staff = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset())

    result = solve_roster(
        RosterSolveInput(
            start_date=START,
            num_days=1,
            shift_length_minutes=240,
            travel_time_minutes=0,
            max_daily_minutes=8 * 60,
            buildings=[building],
            rooms=rooms,
            staff=[staff],
        )
    )
    assert len(_shifts_for(result, 1)) <= 2


def test_travel_time_blocks_back_to_back_shifts_in_different_buildings() -> None:
    """Same wall-clock block in two different buildings requires a travel gap that doesn't
    exist here, so the same staff member can never cover both simultaneously."""
    building_a = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)
    building_b = SolverBuilding(id=2, opening_minutes=480, closing_minutes=720)
    room_a = SolverRoom(id=1, building_id=1, tag_ids=frozenset())
    room_b = SolverRoom(id=2, building_id=2, tag_ids=frozenset())
    staff = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset())

    result = solve_roster(
        RosterSolveInput(
            start_date=START,
            num_days=1,
            shift_length_minutes=240,
            travel_time_minutes=30,
            max_daily_minutes=720,
            buildings=[building_a, building_b],
            rooms=[room_a, room_b],
            staff=[staff],
        )
    )
    # The lone staff member can cover at most one of the two overlapping-time rooms.
    assert len(result.shifts) <= 1


def test_travel_time_allows_gapped_shifts_in_different_buildings() -> None:
    """Staggered opening hours with enough of a gap between buildings should let the same
    staff member work both — this is the cross-building wall-clock case, not simple
    same-building shift-index adjacency."""
    building_a = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)  # 08:00-12:00
    building_b = SolverBuilding(id=2, opening_minutes=780, closing_minutes=1020)  # 13:00-17:00
    room_a = SolverRoom(id=1, building_id=1, tag_ids=frozenset())
    room_b = SolverRoom(id=2, building_id=2, tag_ids=frozenset())
    staff = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset())

    result = solve_roster(
        RosterSolveInput(
            start_date=START,
            num_days=1,
            shift_length_minutes=240,
            travel_time_minutes=30,
            max_daily_minutes=720,
            buildings=[building_a, building_b],
            rooms=[room_a, room_b],
            staff=[staff],
        )
    )
    assert len(result.shifts) == 2


def test_pinned_shift_is_always_present_in_result() -> None:
    building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)
    room = SolverRoom(id=1, building_id=1, tag_ids=frozenset())
    staff = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset())

    result = solve_roster(
        RosterSolveInput(
            start_date=START,
            num_days=1,
            shift_length_minutes=240,
            travel_time_minutes=0,
            max_daily_minutes=720,
            buildings=[building],
            rooms=[room],
            staff=[staff],
            pinned_shifts=[PinnedShift(staff_id=1, room_id=1, date=START, shift_index=0)],
        )
    )
    assert any(s.staff_id == 1 and s.room_id == 1 and s.pinned for s in result.shifts)


def test_indivisible_building_hours_rejected() -> None:
    """08:00-18:00 with 240-minute shifts leaves a 2-hour remainder that would otherwise be
    silently uncovered by any block and never flagged as unfilled."""
    building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=1080)  # 08:00-18:00
    room = SolverRoom(id=1, building_id=1, tag_ids=frozenset())
    staff = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset())

    with pytest.raises(IndivisibleBuildingHoursError):
        solve_roster(
            RosterSolveInput(
                start_date=START,
                num_days=1,
                shift_length_minutes=240,
                travel_time_minutes=0,
                max_daily_minutes=720,
                buildings=[building],
                rooms=[room],
                staff=[staff],
            )
        )


def test_indivisible_hours_ignored_for_building_with_no_rooms() -> None:
    """A Building with no Rooms never produces a slot in the first place (see _all_slots),
    so its hours are irrelevant to this roster — it must not block generation for an
    unrelated Building that happens to also exist in the system."""
    unrelated_building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=1080)
    used_building = SolverBuilding(id=2, opening_minutes=480, closing_minutes=720)
    room = SolverRoom(id=1, building_id=2, tag_ids=frozenset())
    staff = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset())

    result = solve_roster(
        RosterSolveInput(
            start_date=START,
            num_days=1,
            shift_length_minutes=240,
            travel_time_minutes=0,
            max_daily_minutes=720,
            buildings=[unrelated_building, used_building],
            rooms=[room],
            staff=[staff],
        )
    )
    assert len(result.shifts) == 1


def test_infeasible_conflicting_pins_raise_clear_error() -> None:
    """Two pinned shifts that physically overlap in wall-clock time for the same staff
    member can never both be satisfied — the solver must report this clearly rather than
    silently violate the one-room-per-person constraint or crash reading solver values."""
    building_a = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)
    building_b = SolverBuilding(id=2, opening_minutes=480, closing_minutes=720)
    room_a = SolverRoom(id=1, building_id=1, tag_ids=frozenset())
    room_b = SolverRoom(id=2, building_id=2, tag_ids=frozenset())
    staff = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset())

    with pytest.raises(RosterInfeasibleError):
        solve_roster(
            RosterSolveInput(
                start_date=START,
                num_days=1,
                shift_length_minutes=240,
                travel_time_minutes=30,
                max_daily_minutes=720,
                buildings=[building_a, building_b],
                rooms=[room_a, room_b],
                staff=[staff],
                pinned_shifts=[
                    PinnedShift(staff_id=1, room_id=1, date=START, shift_index=0),
                    PinnedShift(staff_id=1, room_id=2, date=START, shift_index=0),
                ],
            )
        )
