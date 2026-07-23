from datetime import date, timedelta

from app.services.solver.model import solve_roster
from app.services.solver.types import (
    EligibilityRule,
    MinimumCountRule,
    RosterSolveInput,
    SolverBuilding,
    SolverRoom,
    SolverStaff,
)

MONDAY = date(2026, 8, 3)
TUESDAY = date(2026, 8, 4)


def test_minimum_count_rule_outranks_room_fill() -> None:
    """With only one qualifying staff member, the solver must cover the tag-scoped
    minimum-count rule even though that leaves an unrestricted room unfilled — Tier 1
    always beats Tier 2, per ADR 0001."""
    building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)
    ed_room = SolverRoom(id=1, building_id=1, tag_ids=frozenset({10}))  # Emergency Department
    general_room = SolverRoom(id=2, building_id=1, tag_ids=frozenset())
    staff = SolverStaff(id=1, role_ids=frozenset({99}), preferred_days=frozenset())

    result = solve_roster(
        RosterSolveInput(
            start_date=MONDAY,
            num_days=1,
            shift_length_minutes=240,
            travel_time_minutes=0,
            max_daily_minutes=720,
            buildings=[building],
            rooms=[ed_room, general_room],
            staff=[staff],
            minimum_count_rules=[
                MinimumCountRule(
                    rule_id=1, role_id=99, building_id=None, tag_id=10, minimum_count=1
                )
            ],
            eligibility_rules=[EligibilityRule(tag_id=10, role_id=99)],
        )
    )
    assert result.minimum_count_violations == []
    assert any(v.room_id == 2 for v in result.room_unfilled_violations)
    assert any(s.room_id == 1 for s in result.shifts)


def test_minimum_count_shortfall_flagged_not_solver_failure() -> None:
    """When nobody qualifies at all, the rule can never be satisfied — the solver still
    returns a roster, with the shortfall surfaced as a violation rather than raising."""
    building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)
    ed_room = SolverRoom(id=1, building_id=1, tag_ids=frozenset({10}))
    staff = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset())  # wrong role

    result = solve_roster(
        RosterSolveInput(
            start_date=MONDAY,
            num_days=1,
            shift_length_minutes=240,
            travel_time_minutes=0,
            max_daily_minutes=720,
            buildings=[building],
            rooms=[ed_room],
            staff=[staff],
            minimum_count_rules=[
                MinimumCountRule(
                    rule_id=1, role_id=99, building_id=None, tag_id=10, minimum_count=1
                )
            ],
        )
    )
    assert len(result.minimum_count_violations) == 1
    assert result.minimum_count_violations[0].shortfall == 1


def test_room_fill_outranks_preferred_days() -> None:
    """A room should still get filled on a staff member's non-preferred day rather than
    stay empty — Tier 2 always beats Tier 3."""
    building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)
    room = SolverRoom(id=1, building_id=1, tag_ids=frozenset())
    # Week 1 (week 0) Monday only.
    staff = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset({(0, 0)}))

    result = solve_roster(
        RosterSolveInput(
            start_date=TUESDAY,
            num_days=1,
            shift_length_minutes=240,
            travel_time_minutes=0,
            max_daily_minutes=720,
            buildings=[building],
            rooms=[room],
            staff=[staff],
        )
    )
    assert result.room_unfilled_violations == []
    assert len(result.shifts) == 1


def test_preferred_day_honored_when_no_coverage_cost() -> None:
    """With two equally-qualified staff and only one preferring the day, the preference
    should be honored since it costs nothing."""
    building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)
    room = SolverRoom(id=1, building_id=1, tag_ids=frozenset())
    prefers_monday = SolverStaff(id=1, role_ids=frozenset(), preferred_days=frozenset({(0, 0)}))
    no_preference = SolverStaff(id=2, role_ids=frozenset(), preferred_days=frozenset())

    result = solve_roster(
        RosterSolveInput(
            start_date=MONDAY,
            num_days=1,
            shift_length_minutes=240,
            travel_time_minutes=0,
            max_daily_minutes=720,
            buildings=[building],
            rooms=[room],
            staff=[prefers_monday, no_preference],
        )
    )
    assert len(result.shifts) == 1
    assert result.shifts[0].staff_id == 1


def test_preferred_day_can_differ_between_weeks() -> None:
    """The same day_of_week can be preferred in one week of the fortnight but not the
    other, and vice versa — each week's preference is honored independently."""
    building = SolverBuilding(id=1, opening_minutes=480, closing_minutes=720)
    room = SolverRoom(id=1, building_id=1, tag_ids=frozenset())
    # A prefers week 1's Monday only; B prefers week 2's Tuesday only.
    prefers_week1_monday = SolverStaff(
        id=1, role_ids=frozenset(), preferred_days=frozenset({(0, 0)})
    )
    prefers_week2_tuesday = SolverStaff(
        id=2, role_ids=frozenset(), preferred_days=frozenset({(1, 1)})
    )

    result = solve_roster(
        RosterSolveInput(
            start_date=MONDAY,
            num_days=14,
            shift_length_minutes=240,
            travel_time_minutes=0,
            max_daily_minutes=720,
            buildings=[building],
            rooms=[room],
            staff=[prefers_week1_monday, prefers_week2_tuesday],
        )
    )
    shifts_by_date = {s.date: s.staff_id for s in result.shifts}
    week1_monday = MONDAY
    week2_tuesday = MONDAY + timedelta(days=8)
    assert shifts_by_date[week1_monday] == 1
    assert shifts_by_date[week2_tuesday] == 2
