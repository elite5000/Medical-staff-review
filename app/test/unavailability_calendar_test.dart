import 'package:app/api/models.dart';
import 'package:app/features/staff/unavailability_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _label(DateTime month) =>
    '${_monthNames[month.month - 1]} ${month.year}';

// UnavailabilityCalendar is only ever embedded inside StaffFormPage's ListView, which is
// how it gets vertical room to lay out a full 5-6 week grid — a bare Scaffold body isn't
// scrollable and overflows the test viewport, so every test wraps it the same way.
Widget _harness(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

Staff _staff({
  required int id,
  required String name,
  List<Unavailability> unavailabilities = const [],
}) => Staff(
  id: id,
  name: name,
  active: true,
  roles: const [],
  preferredDays: const [],
  unavailabilities: unavailabilities,
);

void main() {
  testWidgets('shows the current month by default', (tester) async {
    final now = DateTime.now();

    await tester.pumpWidget(_harness(UnavailabilityCalendar(staff: const [])));
    await tester.pumpAndSettle();

    expect(find.text(_label(DateTime(now.year, now.month))), findsOneWidget);
  });

  testWidgets('navigates to the next month and back', (tester) async {
    final now = DateTime.now();
    final currentLabel = _label(DateTime(now.year, now.month));
    final nextLabel = _label(DateTime(now.year, now.month + 1));

    await tester.pumpWidget(_harness(UnavailabilityCalendar(staff: const [])));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text(nextLabel), findsOneWidget);
    expect(find.text(currentLabel), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text(currentLabel), findsOneWidget);
  });

  testWidgets(
    'shows a dot and legend entry for a staff member unavailable this month',
    (tester) async {
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, 5);
      final alice = _staff(
        id: 1,
        name: 'Dr. Alice',
        unavailabilities: [
          Unavailability(id: 1, staffId: 1, startDate: day, endDate: day),
        ],
      );

      await tester.pumpWidget(
        _harness(UnavailabilityCalendar(staff: [alice])),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Dr. Alice'), findsOneWidget);
      // The legend row's own Text — distinct from the Tooltip message, which isn't rendered
      // as visible text unless triggered.
      expect(find.text('Dr. Alice'), findsOneWidget);
    },
  );

  testWidgets(
    "excludes a staff member's legend entry when their unavailability falls outside the visible month",
    (tester) async {
      final now = DateTime.now();
      // Comfortably outside the current view month regardless of when the test runs.
      final farAway = DateTime(
        now.year,
        now.month,
        1,
      ).add(const Duration(days: 200));
      final bob = _staff(
        id: 2,
        name: 'Dr. Bob',
        unavailabilities: [
          Unavailability(
            id: 2,
            staffId: 2,
            startDate: farAway,
            endDate: farAway,
          ),
        ],
      );

      await tester.pumpWidget(_harness(UnavailabilityCalendar(staff: [bob])));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Dr. Bob'), findsNothing);
      expect(find.text('Dr. Bob'), findsNothing);
    },
  );

  testWidgets('bolds the highlighted staff member in the legend', (
    tester,
  ) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, 5);
    final alice = _staff(
      id: 1,
      name: 'Dr. Alice',
      unavailabilities: [
        Unavailability(id: 1, staffId: 1, startDate: day, endDate: day),
      ],
    );

    await tester.pumpWidget(
      _harness(UnavailabilityCalendar(staff: [alice], highlightStaffId: 1)),
    );
    await tester.pumpAndSettle();

    final legendText = tester.widget<Text>(find.text('Dr. Alice'));
    expect(legendText.style?.fontWeight, FontWeight.bold);
  });
}
