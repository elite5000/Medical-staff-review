from app.services.solver.timing import shift_window_minutes, shifts_conflict, windows_conflict


def test_shift_window_minutes_computes_start_and_end() -> None:
    assert shift_window_minutes(480, 2, 60) == (600, 660)


def test_windows_conflict_same_building_adjacent_blocks_are_compatible() -> None:
    # Sequential same-building blocks touch with zero gap, which satisfies a same-building
    # Travel Time requirement of zero.
    assert windows_conflict(1, 480, 720, 1, 720, 960, 30) is False


def test_windows_conflict_different_building_needs_travel_gap() -> None:
    assert windows_conflict(1, 480, 720, 2, 720, 960, 30) is True  # zero gap, needs 30
    assert windows_conflict(1, 480, 720, 2, 750, 960, 30) is False  # exactly 30-minute gap


def test_shifts_conflict_wraps_window_computation() -> None:
    # Building 1: 08:00-12:00 in one 240-minute block (index 0).
    # Building 2 opens at 13:00 — a 60-minute gap, enough for 30 minutes of Travel Time.
    assert shifts_conflict(1, 480, 0, 2, 780, 0, 240, 30) is False
    # Building 2 opens right at 12:00 instead — no gap at all.
    assert shifts_conflict(1, 480, 0, 2, 720, 0, 240, 30) is True
