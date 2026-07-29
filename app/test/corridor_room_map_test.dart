import 'package:app/api/models.dart';
import 'package:app/features/rosters/corridor_room_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Room _room(int id) =>
    Room(id: id, name: 'Room $id', buildingId: 1, tags: const []);

Widget _harness(List<Room> rooms, {ValueChanged<int>? onTap}) => MaterialApp(
  home: Scaffold(
    body: CorridorRoomMap(rooms: rooms, onRoomTap: onTap ?? (_) {}),
  ),
);

void main() {
  testWidgets('shows an empty state when the building has no rooms', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const []));
    expect(find.text('No rooms in this building yet.'), findsOneWidget);
  });

  testWidgets('renders all rooms for a single partially-filled corridor (1 room)', (
    tester,
  ) async {
    await tester.pumpWidget(_harness([_room(1)]));
    expect(find.text('Room 1'), findsOneWidget);
  });

  testWidgets('renders exactly one corridor for 8 rooms', (tester) async {
    final rooms = List.generate(8, (i) => _room(i + 1));
    await tester.pumpWidget(_harness(rooms));
    for (final r in rooms) {
      expect(find.text(r.name), findsOneWidget);
    }
  });

  testWidgets('spills into a second corridor for 9 rooms', (tester) async {
    final rooms = List.generate(9, (i) => _room(i + 1));
    int? tapped;
    await tester.pumpWidget(_harness(rooms, onTap: (id) => tapped = id));
    for (final r in rooms) {
      expect(find.text(r.name), findsOneWidget);
    }

    await tester.tap(find.text('Room 9'));
    expect(tapped, 9);
  });

  testWidgets('renders two full corridors for 16 rooms', (tester) async {
    final rooms = List.generate(16, (i) => _room(i + 1));
    await tester.pumpWidget(_harness(rooms));
    for (final r in rooms) {
      expect(find.text(r.name), findsOneWidget);
    }
  });

  testWidgets('tapping a room tile invokes onRoomTap with the room id', (
    tester,
  ) async {
    int? tapped;
    await tester.pumpWidget(
      _harness([_room(1), _room(2)], onTap: (id) => tapped = id),
    );

    await tester.tap(find.text('Room 2'));
    expect(tapped, 2);
  });
}
