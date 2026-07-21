"""
The roster solver: implements the hard/soft constraint hierarchy from
docs/adr/0001-roster-solver-constraint-hierarchy.md using Google OR-Tools CP-SAT.

Hard constraints (never violated): one-person-per-room, one-room-per-person (including the
Travel Time buffer when consecutive shifts are in different Buildings), Max Daily Hours,
Unavailability, and eligibility-restriction Rules. These are either baked into which
`assign` variables get created at all (Unavailability, eligibility) or enforced as ordinary
CP-SAT constraints (the rest).

Soft goals, in strict priority order via widely-separated objective weights so a higher
tier is never sacrificed for a lower one: (1) minimum-count Rule shortfalls, (2) unfilled
room-hours, (3) non-preferred-day assignments.
"""

from collections import defaultdict
from dataclasses import dataclass
from datetime import date, timedelta

from ortools.sat.python import cp_model

from app.services.solver.types import (
    MinimumCountViolation,
    RoomUnfilledViolation,
    RosterSolveInput,
    RosterSolveResult,
    SolvedShift,
    SolverBuilding,
    SolverRoom,
)

# Widely-separated so tier N+1's total possible cost can never outweigh a single unit of
# tier N. With len(dates) <= 14 and a handful of blocks/rooms per day, the maximum possible
# total unfilled-room-hours or preferred-day misses is far below 1_000, and the maximum
# possible total minimum-count shortfall is far below 1_000_000 — comfortable headroom
# rather than a tight bound, but documented here so the assumption is visible if the model
# ever scales up by orders of magnitude.
_WEIGHT_MINIMUM_COUNT = 1_000_000
_WEIGHT_ROOM_FILL = 1_000
_WEIGHT_PREFERRED_DAY = 1


@dataclass(frozen=True)
class _Slot:
    """One (room, shift_index) time block, with its wall-clock window for that day."""

    room: SolverRoom
    shift_index: int
    start_minutes: int
    end_minutes: int


def _blocks_per_day(building: SolverBuilding, shift_length_minutes: int) -> int:
    # Assumes opening hours divide evenly into shift blocks (see CONTEXT.md's Shift entry);
    # any remainder minutes are simply not covered by a schedulable block.
    return max(0, (building.closing_minutes - building.opening_minutes) // shift_length_minutes)


def _all_slots(
    rooms: list[SolverRoom],
    buildings_by_id: dict[int, SolverBuilding],
    shift_length_minutes: int,
) -> list[_Slot]:
    slots = []
    for room in rooms:
        building = buildings_by_id[room.building_id]
        for shift_index in range(_blocks_per_day(building, shift_length_minutes)):
            start = building.opening_minutes + shift_index * shift_length_minutes
            slots.append(_Slot(room, shift_index, start, start + shift_length_minutes))
    return slots


def _conflicting_slot_pairs(
    slots: list[_Slot], travel_time_minutes: int
) -> list[tuple[_Slot, _Slot]]:
    """
    Slot pairs a single staff member can never occupy both of on the same day: either they
    physically overlap (same or different building), or — for different buildings only —
    the gap between them is shorter than the Travel Time setting. Same-building sequential
    blocks are adjacent with zero gap, which satisfies a same-building requirement of zero
    travel time, so they are correctly *not* flagged.
    """
    conflicts = []
    for i, a in enumerate(slots):
        for b in slots[i + 1 :]:
            if a.room.id == b.room.id:
                continue
            required_gap = travel_time_minutes if a.room.building_id != b.room.building_id else 0
            compatible = a.end_minutes + required_gap <= b.start_minutes or (
                b.end_minutes + required_gap <= a.start_minutes
            )
            if not compatible:
                conflicts.append((a, b))
    return conflicts


def _eligible_role_ids_for_room(
    room: SolverRoom, eligibility_by_tag: dict[int, set[int]]
) -> frozenset[int] | None:
    """None means unrestricted (no eligibility_restriction rule applies to any of the
    room's Tags). Otherwise, the union of every applicable Tag's allowed roles — matching
    the union (not intersection) semantics resolved in CONTEXT.md."""
    applicable = [eligibility_by_tag[t] for t in room.tag_ids if t in eligibility_by_tag]
    if not applicable:
        return None
    allowed: set[int] = set()
    for roles in applicable:
        allowed |= roles
    return frozenset(allowed)


def _is_unavailable(
    staff_id: int, day: date, unavailable_ranges: dict[int, list[tuple[date, date]]]
) -> bool:
    return any(start <= day <= end for start, end in unavailable_ranges.get(staff_id, []))


def _rule_scope_slots(
    rule_building_id: int | None,
    rule_tag_id: int | None,
    slots: list[_Slot],
) -> dict[tuple[int, int], list[_Slot]]:
    """
    Buckets of (building_id, shift_index) -> qualifying Slots for a minimum-count Rule.
    A building-scoped rule counts anyone in that building; a tag-scoped rule counts anyone
    in a Tag-carrying room, bucketed per building since shift timing is building-relative
    (see the solver's module docstring / ADR 0001 for why coverage can't be compared across
    buildings directly). Keying by building_id (not just shift_index) matters here: a
    tag-scoped rule can span rooms in several buildings that happen to share a shift_index
    value, and those must stay separate buckets, not merge into one.
    """
    buckets: dict[tuple[int, int], list[_Slot]] = defaultdict(list)
    for slot in slots:
        if rule_building_id is not None and slot.room.building_id != rule_building_id:
            continue
        if rule_tag_id is not None and rule_tag_id not in slot.room.tag_ids:
            continue
        buckets[(slot.room.building_id, slot.shift_index)].append(slot)
    return buckets


def solve_roster(data: RosterSolveInput) -> RosterSolveResult:
    model = cp_model.CpModel()
    dates = [data.start_date + timedelta(days=i) for i in range(data.num_days)]
    buildings_by_id = {b.id: b for b in data.buildings}
    slots = _all_slots(data.rooms, buildings_by_id, data.shift_length_minutes)
    conflicting_pairs = _conflicting_slot_pairs(slots, data.travel_time_minutes)

    eligibility_by_tag: dict[int, set[int]] = defaultdict(set)
    for eligibility_rule in data.eligibility_rules:
        eligibility_by_tag[eligibility_rule.tag_id].add(eligibility_rule.role_id)
    eligible_roles_by_room = {
        room.id: _eligible_role_ids_for_room(room, eligibility_by_tag) for room in data.rooms
    }

    unavailable_ranges: dict[int, list[tuple[date, date]]] = defaultdict(list)
    for u in data.unavailabilities:
        unavailable_ranges[u.staff_id].append((u.start_date, u.end_date))

    pinned_lookup = {(p.staff_id, p.room_id, p.date, p.shift_index) for p in data.pinned_shifts}
    minimum_count_rules_by_id = {r.rule_id: r for r in data.minimum_count_rules}

    max_blocks_per_day = (
        data.max_daily_minutes // data.shift_length_minutes if data.shift_length_minutes else 0
    )

    # --- Variables ---------------------------------------------------------------
    # assign[(staff_id, day, room_id, shift_index)] = 1 iff that staff works that room-slot.
    # Skipping ineligible/unavailable combos up front keeps the model small and makes two
    # hard constraints (eligibility, Unavailability) true "for free", by construction.
    assign: dict[tuple[int, date, int, int], cp_model.IntVar] = {}
    for staff in data.staff:
        for day in dates:
            if _is_unavailable(staff.id, day, unavailable_ranges):
                continue
            for slot in slots:
                allowed_roles = eligible_roles_by_room[slot.room.id]
                is_pinned = (staff.id, slot.room.id, day, slot.shift_index) in pinned_lookup
                if not is_pinned and allowed_roles is not None:
                    if not (staff.role_ids & allowed_roles):
                        continue
                key = (staff.id, day, slot.room.id, slot.shift_index)
                var_name = f"assign_s{staff.id}_d{day}_r{slot.room.id}_i{slot.shift_index}"
                assign[key] = model.new_bool_var(var_name)

    # Pinned assignments are forced to 1 — they still flow through every aggregate below
    # (minimum-count actuals, daily-hours sums, room-fill) exactly like any other shift.
    for pinned in data.pinned_shifts:
        key = (pinned.staff_id, pinned.date, pinned.room_id, pinned.shift_index)
        if key not in assign:
            var_name = (
                f"assign_pinned_s{pinned.staff_id}_d{pinned.date}"
                f"_r{pinned.room_id}_i{pinned.shift_index}"
            )
            assign[key] = model.new_bool_var(var_name)
        model.add(assign[key] == 1)

    # --- Hard constraints ----------------------------------------------------------
    # One assignment per room-slot per day.
    by_room_slot_day: dict[tuple[int, int, date], list[cp_model.IntVar]] = defaultdict(list)
    for (_staff_id, day, room_id, shift_index), var in assign.items():
        by_room_slot_day[(room_id, shift_index, day)].append(var)
    for var_list in by_room_slot_day.values():
        if len(var_list) > 1:
            model.add(sum(var_list) <= 1)

    # Temporal exclusivity per staff (one-room-per-person + Travel Time), precomputed once
    # since the daily schedule shape repeats identically across the whole roster period.
    for day in dates:
        for staff in data.staff:
            for slot_a, slot_b in conflicting_pairs:
                key_a = (staff.id, day, slot_a.room.id, slot_a.shift_index)
                key_b = (staff.id, day, slot_b.room.id, slot_b.shift_index)
                if key_a in assign and key_b in assign:
                    model.add(assign[key_a] + assign[key_b] <= 1)

    # Max Daily Hours.
    by_staff_day: dict[tuple[int, date], list[cp_model.IntVar]] = defaultdict(list)
    for (staff_id, day, _room_id, _shift_index), var in assign.items():
        by_staff_day[(staff_id, day)].append(var)
    for var_list in by_staff_day.values():
        model.add(sum(var_list) <= max_blocks_per_day)

    # --- Soft goals, tiered objective ----------------------------------------------
    objective_terms = []

    # Tier 1: minimum-count Rule shortfalls, keyed by (rule_id, building_id, day, shift_index)
    # — building_id must stay in the key, since a tag-scoped rule's buckets can span several
    # buildings that share the same shift_index value.
    minimum_count_shortfall_vars: dict[tuple[int, int, date, int], cp_model.IntVar] = {}
    for minimum_count_rule in data.minimum_count_rules:
        role_staff_ids = {s.id for s in data.staff if minimum_count_rule.role_id in s.role_ids}
        buckets = _rule_scope_slots(
            minimum_count_rule.building_id, minimum_count_rule.tag_id, slots
        )
        for (building_id, shift_index), bucket_slots in buckets.items():
            for day in dates:
                actual_vars = [
                    assign[(staff_id, day, slot.room.id, slot.shift_index)]
                    for slot in bucket_slots
                    for staff_id in role_staff_ids
                    if (staff_id, day, slot.room.id, slot.shift_index) in assign
                ]
                rule_id = minimum_count_rule.rule_id
                var_name = f"shortfall_rule{rule_id}_b{building_id}_d{day}_i{shift_index}"
                shortfall = model.new_int_var(0, minimum_count_rule.minimum_count, var_name)
                model.add(shortfall >= minimum_count_rule.minimum_count - sum(actual_vars))
                minimum_count_shortfall_vars[
                    (minimum_count_rule.rule_id, building_id, day, shift_index)
                ] = shortfall
                objective_terms.append(_WEIGHT_MINIMUM_COUNT * shortfall)

    # Tier 2: unfilled room-hours. Slots with zero eligible staff at all get no variable
    # here (nothing to optimize) but are still reported as violations below, unconditionally.
    unfilled_vars: dict[tuple[int, date, int], cp_model.IntVar] = {}
    assign_by_room_slot_day: dict[tuple[int, int, date], list[cp_model.IntVar]] = defaultdict(list)
    for (_staff_id, day, room_id, shift_index), var in assign.items():
        assign_by_room_slot_day[(room_id, shift_index, day)].append(var)
    for slot in slots:
        for day in dates:
            candidates = assign_by_room_slot_day.get((slot.room.id, slot.shift_index, day), [])
            if not candidates:
                continue
            occupied = model.new_int_var(
                0, 1, f"occupied_r{slot.room.id}_d{day}_i{slot.shift_index}"
            )
            model.add(occupied == sum(candidates))
            unfilled = model.new_int_var(
                0, 1, f"unfilled_r{slot.room.id}_d{day}_i{slot.shift_index}"
            )
            model.add(unfilled == 1 - occupied)
            unfilled_vars[(slot.room.id, day, slot.shift_index)] = unfilled
            objective_terms.append(_WEIGHT_ROOM_FILL * unfilled)

    # Tier 3: preferred-day fit. Staff with no declared preference are neutral either way.
    # Staff who *do* have a preference get a small reward for matches and a small penalty
    # for misses, so a tie between a matching and an indifferent staff member breaks toward
    # the one who actually wants that day — not just "avoid non-preferred days" in isolation.
    assign_by_staff_day: dict[tuple[int, date], list[cp_model.IntVar]] = defaultdict(list)
    for (staff_id, day, _room_id, _shift_index), var in assign.items():
        assign_by_staff_day[(staff_id, day)].append(var)
    for staff in data.staff:
        if not staff.preferred_days:
            continue
        for day in dates:
            day_vars = assign_by_staff_day.get((staff.id, day), [])
            weight = (
                -_WEIGHT_PREFERRED_DAY
                if day.weekday() in staff.preferred_days
                else _WEIGHT_PREFERRED_DAY
            )
            objective_terms.extend(weight * v for v in day_vars)

    if objective_terms:
        model.minimize(sum(objective_terms))

    solver = cp_model.CpSolver()
    solver.parameters.max_time_in_seconds = 30
    solver.solve(model)

    solved_shifts = [
        SolvedShift(
            staff_id=staff_id,
            room_id=room_id,
            date=day,
            shift_index=shift_index,
            pinned=(staff_id, room_id, day, shift_index) in pinned_lookup,
        )
        for (staff_id, day, room_id, shift_index), var in assign.items()
        if solver.value(var) == 1
    ]

    minimum_count_violations = [
        MinimumCountViolation(
            rule_id=rule_id,
            building_id=minimum_count_rules_by_id[rule_id].building_id,
            tag_id=minimum_count_rules_by_id[rule_id].tag_id,
            date=day,
            shift_index=shift_index,
            shortfall=solver.value(var),
        )
        for (rule_id, _building_id, day, shift_index), var in minimum_count_shortfall_vars.items()
        if solver.value(var) > 0
    ]

    room_unfilled_violations = []
    for slot in slots:
        for day in dates:
            slot_key = (slot.room.id, day, slot.shift_index)
            if slot_key in unfilled_vars:
                if solver.value(unfilled_vars[slot_key]) == 1:
                    room_unfilled_violations.append(
                        RoomUnfilledViolation(
                            room_id=slot.room.id, date=day, shift_index=slot.shift_index
                        )
                    )
            else:
                # No eligible staff existed for this room-slot-day at all.
                room_unfilled_violations.append(
                    RoomUnfilledViolation(
                        room_id=slot.room.id, date=day, shift_index=slot.shift_index
                    )
                )

    return RosterSolveResult(
        shifts=solved_shifts,
        minimum_count_violations=minimum_count_violations,
        room_unfilled_violations=room_unfilled_violations,
    )
