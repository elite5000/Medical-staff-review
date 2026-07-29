import 'package:app/features/rosters/shift_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ShiftDisplayEntry _entry(DateTime date, int start, String label) =>
    ShiftDisplayEntry(
      date: date,
      startMinutes: start,
      endMinutes: start + 60,
      label: label,
    );

Widget _harness(TwoWeekShiftCalendar calendar) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: calendar)));

void main() {
  testWidgets('renders a 14-day page starting at rangeStart', (tester) async {
    final rangeStart = DateTime(2026, 1, 5); // Monday
    final rangeEnd = DateTime(2026, 1, 18); // exactly 14 days later
    await tester.pumpWidget(
      _harness(
        TwoWeekShiftCalendar(
          entries: const [],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      ),
    );

    expect(find.text('2026-01-05 – 2026-01-18'), findsOneWidget);
    expect(find.text('Mon 5'), findsOneWidget);
    expect(find.text('Sun 18'), findsOneWidget);
  });

  testWidgets('groups entries by day and sorts by start time within a day', (
    tester,
  ) async {
    final rangeStart = DateTime(2026, 1, 5);
    final rangeEnd = DateTime(2026, 1, 18);
    final day = DateTime(2026, 1, 6);
    await tester.pumpWidget(
      _harness(
        TwoWeekShiftCalendar(
          entries: [
            _entry(day, 600, 'Hospital - Room B - Dr. Bob'),
            _entry(day, 480, 'Hospital - Room A - Dr. Alice'),
          ],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      ),
    );

    final earlier = tester.getTopLeft(
      find.textContaining('Hospital - Room A - Dr. Alice'),
    );
    final later = tester.getTopLeft(
      find.textContaining('Hospital - Room B - Dr. Bob'),
    );
    expect(earlier.dy, lessThan(later.dy));
    expect(find.textContaining('08:00–09:00'), findsOneWidget);
    expect(find.textContaining('10:00–11:00'), findsOneWidget);
  });

  testWidgets('prev/next disable at the inclusive range boundaries', (
    tester,
  ) async {
    final rangeStart = DateTime(2026, 1, 5);
    final rangeEnd = DateTime(2026, 1, 18); // exactly one 14-day page
    await tester.pumpWidget(
      _harness(
        TwoWeekShiftCalendar(
          entries: const [],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      ),
    );

    final prevButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    final nextButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(prevButton.onPressed, isNull);
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('paging forward reaches the final page and then disables next', (
    tester,
  ) async {
    final rangeStart = DateTime(2026, 1, 5);
    final rangeEnd = DateTime(2026, 1, 25); // 21 days: two pages
    await tester.pumpWidget(
      _harness(
        TwoWeekShiftCalendar(
          entries: const [],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      ),
    );

    expect(find.text('2026-01-05 – 2026-01-18'), findsOneWidget);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('2026-01-19 – 2026-02-01'), findsOneWidget);
    final nextButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(nextButton.onPressed, isNull);
    final prevButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_left),
    );
    expect(prevButton.onPressed, isNotNull);
  });
}
