import 'package:app/api/models.dart';
import 'package:app/features/rosters/roster_map_view.dart';
import 'package:app/features/rosters/shift_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Building _building(int id, String name) =>
    Building(id: id, name: name, openingMinutes: 480, closingMinutes: 1080);

Room _room(int id, int buildingId, String name) =>
    Room(id: id, name: name, buildingId: buildingId, tags: const []);

Staff _staff(int id, String name) => Staff(
  id: id,
  name: name,
  active: true,
  roles: const [],
  preferredDays: const [],
  unavailabilities: const [],
);

AppSettings _settings() => AppSettings(
  shiftLengthMinutes: 60,
  travelTimeMinutes: 15,
  maxDailyMinutes: 480,
);

RosterLookups _lookups({
  List<Room> rooms = const [],
  List<Building> buildings = const [],
  List<Staff> staff = const [],
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
  testWidgets(
    'drills from buildings to rooms to a room calendar and back via breadcrumb',
    (tester) async {
      final shift = Shift(
        id: 1,
        roomId: 1,
        staffId: 1,
        date: DateTime(2026, 1, 6),
        shiftIndex: 0,
        pinned: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RosterMapView(
              roster: _roster([shift]),
              lookups: _lookups(
                rooms: [_room(1, 1, 'Room A')],
                buildings: [_building(1, 'Hospital')],
                staff: [_staff(1, 'Dr. Alice')],
              ),
            ),
          ),
        ),
      );

      // Buildings level.
      expect(find.text('Buildings'), findsOneWidget);
      expect(find.text('Hospital'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);

      await tester.tap(find.text('Hospital'));
      await tester.pumpAndSettle();

      // Rooms level.
      expect(find.text('Hospital'), findsOneWidget); // breadcrumb title
      expect(find.text('Room A'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.tap(find.text('Room A'));
      await tester.pumpAndSettle();

      // Calendar level: shows shift for ALL staff in the room, not filtered.
      expect(find.text('Hospital > Room A'), findsOneWidget);
      expect(
        find.textContaining('Hospital - Room A - Dr. Alice'),
        findsOneWidget,
      );

      // Back twice returns to buildings.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Hospital'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Buildings'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    },
  );

  testWidgets('shows an empty state when there are no buildings', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RosterMapView(roster: _roster(const []), lookups: _lookups()),
        ),
      ),
    );

    expect(find.text('No buildings yet.'), findsOneWidget);
  });

  testWidgets('rooms level only shows rooms belonging to the selected building', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RosterMapView(
            roster: _roster(const []),
            lookups: _lookups(
              rooms: [_room(1, 1, 'Room A'), _room(2, 2, 'Room B')],
              buildings: [_building(1, 'Hospital'), _building(2, 'Clinic')],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Hospital'));
    await tester.pumpAndSettle();

    expect(find.text('Room A'), findsOneWidget);
    expect(find.text('Room B'), findsNothing);
  });
}
