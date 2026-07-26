"""
Shared wall-clock timing math for shift blocks. shift_index is Building-relative (see
model.py's module docstring), so anything comparing two shifts for a conflict — the solver
itself, or a manual edit in roster_service.py — must go through here rather than comparing
shift_index values directly.
"""


def shift_window_minutes(
    building_opening_minutes: int, shift_index: int, shift_length_minutes: int
) -> tuple[int, int]:
    start = building_opening_minutes + shift_index * shift_length_minutes
    return start, start + shift_length_minutes


def windows_conflict(
    building_a_id: int,
    start_a_minutes: int,
    end_a_minutes: int,
    building_b_id: int,
    start_b_minutes: int,
    end_b_minutes: int,
    travel_time_minutes: int,
) -> bool:
    """True if a single staff member can never occupy both windows on the same day: either
    they physically overlap, or — for different Buildings only — the gap between them is
    shorter than the Travel Time setting. Same-building sequential blocks are adjacent with
    zero gap, which satisfies a same-building requirement of zero travel time."""
    required_gap = travel_time_minutes if building_a_id != building_b_id else 0
    compatible = end_a_minutes + required_gap <= start_b_minutes or (
        end_b_minutes + required_gap <= start_a_minutes
    )
    return not compatible


def shifts_conflict(
    building_a_id: int,
    opening_a_minutes: int,
    shift_index_a: int,
    building_b_id: int,
    opening_b_minutes: int,
    shift_index_b: int,
    shift_length_minutes: int,
    travel_time_minutes: int,
) -> bool:
    start_a, end_a = shift_window_minutes(opening_a_minutes, shift_index_a, shift_length_minutes)
    start_b, end_b = shift_window_minutes(opening_b_minutes, shift_index_b, shift_length_minutes)
    return windows_conflict(
        building_a_id, start_a, end_a, building_b_id, start_b, end_b, travel_time_minutes
    )
