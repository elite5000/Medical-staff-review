import 'package:app/api/models.dart';
import 'package:app/features/rosters/roster_personal_view.dart';
import 'package:app/features/rosters/shift_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Building _building() =>
    Building(id: 1, name: 'Hospital', openingMinutes: 480, closingMinutes: 1080);

Room _room(int id, String name) =>
    Room(id: id, name: name, buildingId: 1, tags: const []);

Staff _staff(int id, String name) => Staff(
  id: id,
  name: name,
  active: true,
  roles: const [],
  preferredDays: const [],
  unavailabilities: const [],
);

AppSettings _settings() =>
    AppSettings(shiftLengthMinutes: 60, travelTimeMinutes: 15, maxDailyMinutes: 480);

RosterLookups _lookups({
  required List<Staff> staff,
  required List<Room> rooms,
  required List<Building> buildings,
}) => RosterLookups(
  rooms: rooms,
  buildings: buildings,
  staff: staff,
  settings: _settings(),
);

RosterDetail _roster(List<Shift> shifts) => RosterDetail(
  id: 1,
  startDate: DateTime(2026, 1, 5),
  endDate: DateTime(2026, 1, 18),
  generatedAt: DateTime(2026, 1, 1),
  hasViolations: false,
  shifts: shifts,
  violations: const [],
);

void main() {
  testWidgets('shows a placeholder until a staff member is selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RosterPersonalView(
            roster: _roster(const []),
            lookups: _lookups(
              staff: [_staff(1, 'Dr. Alice'), _staff(2, 'Dr. Bob')],
              rooms: [_room(1, 'Room A')],
              buildings: [_building()],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Pick a staff member to see their roster.'), findsOneWidget);
  });

  testWidgets('selecting a staff member shows only their shifts, correctly labeled', (
    tester,
  ) async {
    final shifts = [
      Shift(
        id: 1,
        roomId: 1,
        staffId: 1,
        date: DateTime(2026, 1, 6),
        shiftIndex: 0,
        pinned: false,
      ),
      Shift(
        id: 2,
        roomId: 1,
        staffId: 2,
        date: DateTime(2026, 1, 6),
        shiftIndex: 1,
        pinned: false,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RosterPersonalView(
            roster: _roster(shifts),
            lookups: _lookups(
              staff: [_staff(1, 'Dr. Alice'), _staff(2, 'Dr. Bob')],
              rooms: [_room(1, 'Room A')],
              buildings: [_building()],
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dr. Alice').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Hospital - Room A - Dr. Alice'),
      findsOneWidget,
    );
    expect(find.textContaining('Dr. Bob'), findsNothing);
  });
}
