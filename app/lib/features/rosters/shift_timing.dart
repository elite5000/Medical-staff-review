import '../../api/models.dart';

/// Mirrors backend/app/services/solver/timing.py's shift_window_minutes. The backend never
/// stores a shift's clock time — only its Building-relative shift_index — so this must be
/// re-derived client-side for any UI that wants to show real times.
(int startMinutes, int endMinutes) shiftWindowMinutes(
  Shift shift,
  Building building,
  AppSettings settings,
) {
  final start =
      building.openingMinutes + shift.shiftIndex * settings.shiftLengthMinutes;
  return (start, start + settings.shiftLengthMinutes);
}
