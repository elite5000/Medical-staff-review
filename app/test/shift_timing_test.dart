import 'package:app/api/models.dart';
import 'package:app/features/rosters/shift_timing.dart';
import 'package:test/test.dart';

void main() {
  final building = Building(
    id: 1,
    name: 'Hospital',
    openingMinutes: 480, // 08:00
    closingMinutes: 1080, // 18:00
  );
  final settings = AppSettings(
    shiftLengthMinutes: 60,
    travelTimeMinutes: 15,
    maxDailyMinutes: 480,
  );

  Shift shiftAt(int shiftIndex) => Shift(
    id: 1,
    roomId: 1,
    staffId: 1,
    date: DateTime(2026, 1, 5),
    shiftIndex: shiftIndex,
    pinned: false,
  );

  group('shiftWindowMinutes', () {
    test('shift 0 starts at building opening', () {
      final (start, end) = shiftWindowMinutes(shiftAt(0), building, settings);
      expect(start, 480);
      expect(end, 540);
    });

    test('offsets by shiftIndex * shiftLengthMinutes', () {
      final (start, end) = shiftWindowMinutes(shiftAt(3), building, settings);
      expect(start, 480 + 3 * 60);
      expect(end, 480 + 4 * 60);
    });

    test(
      'can extend past midnight (1440) without asserting like TimeOfDay would',
      () {
        final lateBuilding = Building(
          id: 2,
          name: 'Overnight',
          openingMinutes: 1380, // 23:00
          closingMinutes: 1440,
        );
        final (start, end) = shiftWindowMinutes(
          shiftAt(1),
          lateBuilding,
          settings,
        );
        expect(start, 1440);
        expect(end, 1500);
      },
    );
  });

  // formatClockMinutes itself lives in api/models.dart (shared with buildings_page.dart);
  // this only covers the wrap: true mode this feature relies on for shift windows that can
  // run past a single day.
  group('formatClockMinutes(wrap: true)', () {
    test('formats zero-padded HH:mm', () {
      expect(formatClockMinutes(480, wrap: true), '08:00');
      expect(formatClockMinutes(65, wrap: true), '01:05');
    });

    test('wraps minutes at/past 1440 back to a 0-23 hour', () {
      expect(formatClockMinutes(1440, wrap: true), '00:00');
      expect(formatClockMinutes(1500, wrap: true), '01:00');
    });
  });
}
