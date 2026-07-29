import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/connection/connection_info.dart';
import 'package:app/features/tags/bulk_apply_tag_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Two buildings: "North Wing" with rooms 1 & 2 (room 2 already carries "Surgery"),
/// "South Wing" with room 3.
Map<String, dynamic> _building(int id, String name) => {
  'id': id,
  'name': name,
  'opening_minutes': 480,
  'closing_minutes': 1080,
};

Map<String, dynamic> _room(
  int id,
  String name,
  int buildingId, [
  List<Map<String, dynamic>> tags = const [],
]) => {'id': id, 'name': name, 'building_id': buildingId, 'tags': tags};

const _surgery = {'id': 10, 'name': 'Surgery'};
const _emergency = {'id': 11, 'name': 'Emergency'};

/// Returns the MockClient plus a mutable log of the apply-to-rooms bodies it received, so a
/// test can assert both what was sent and that the page refetched afterwards.
({http.Client client, List<Map<String, dynamic>> applied}) _mockBackend() {
  final applied = <Map<String, dynamic>>[];
  var rooms = <Map<String, dynamic>>[
    _room(1, 'Room 1', 1),
    _room(2, 'Room 2', 1, [_surgery]),
    _room(3, 'Room 3', 2),
  ];

  final client = MockClient((request) async {
    if (request.method == 'GET' && request.url.path == '/buildings') {
      return http.Response(
        jsonEncode([_building(1, 'North Wing'), _building(2, 'South Wing')]),
        200,
      );
    }
    if (request.method == 'GET' && request.url.path == '/rooms') {
      return http.Response(jsonEncode(rooms), 200);
    }
    if (request.method == 'GET' && request.url.path == '/tags') {
      return http.Response(jsonEncode([_emergency, _surgery]), 200);
    }
    if (request.method == 'POST' &&
        request.url.path == '/tags/11/apply-to-rooms') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      applied.add(body);
      final ids = (body['room_ids'] as List).cast<int>().toSet();
      // Mirror the backend's additive union so a refetch shows the new chips.
      rooms = rooms.map((r) {
        if (!ids.contains(r['id'])) return r;
        final tags = (r['tags'] as List).cast<Map<String, dynamic>>();
        if (tags.any((t) => t['id'] == _emergency['id'])) return r;
        return {
          ...r,
          'tags': [...tags, _emergency],
        };
      }).toList();
      return http.Response(
        jsonEncode(rooms.where((r) => ids.contains(r['id'])).toList()),
        200,
      );
    }
    return http.Response('not found', 404);
  });

  return (client: client, applied: applied);
}

Future<void> _pumpPage(WidgetTester tester, http.Client client) async {
  final api = ApiClient(
    ConnectionInfo(host: 'test', port: 1234),
    httpClient: client,
  );
  await tester.pumpWidget(MaterialApp(home: BulkApplyTagPage(api: api)));
  await tester.pumpAndSettle();
}

Checkbox _buildingCheckbox(WidgetTester tester, int id) =>
    tester.widget<Checkbox>(find.byKey(Key('building-checkbox-$id')));

CheckboxListTile _roomCheckbox(WidgetTester tester, int id) =>
    tester.widget<CheckboxListTile>(find.byKey(Key('room-checkbox-$id')));

/// The picker renders the selected tag's name in the field *and* in the (offstage) menu
/// item, so tapping by text needs the visible one.
Future<void> _selectTag(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const Key('tag-picker')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _expandBuilding(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

/// Scoped to the SegmentedButton: "Tag" is also the tag picker's label, so a bare
/// find.text('Tag') is ambiguous.
Future<void> _selectMode(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(SegmentedButton<SearchMode>),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('selecting a building selects all of its rooms', (tester) async {
    await _pumpPage(tester, _mockBackend().client);

    expect(_buildingCheckbox(tester, 1).value, isFalse);

    await tester.tap(find.byKey(const Key('building-checkbox-1')));
    await tester.pumpAndSettle();

    expect(_buildingCheckbox(tester, 1).value, isTrue);
    expect(find.text('2 of 2 selected'), findsOneWidget);
    expect(find.text('2 rooms selected'), findsOneWidget);
    // The other building is untouched.
    expect(_buildingCheckbox(tester, 2).value, isFalse);

    await _expandBuilding(tester, 'North Wing');
    expect(_roomCheckbox(tester, 1).value, isTrue);
    expect(_roomCheckbox(tester, 2).value, isTrue);
  });

  testWidgets(
    'deselecting one room under a full building drops it to indeterminate',
    (tester) async {
      await _pumpPage(tester, _mockBackend().client);

      await tester.tap(find.byKey(const Key('building-checkbox-1')));
      await tester.pumpAndSettle();
      await _expandBuilding(tester, 'North Wing');

      await tester.tap(find.byKey(const Key('room-checkbox-2')));
      await tester.pumpAndSettle();

      // tristate: null renders as the dash, i.e. "some but not all".
      expect(_buildingCheckbox(tester, 1).value, isNull);
      expect(_roomCheckbox(tester, 1).value, isTrue);
      expect(_roomCheckbox(tester, 2).value, isFalse);
      expect(find.text('1 of 2 selected'), findsOneWidget);

      // Tapping a partly-selected building fills it up rather than emptying it.
      await tester.tap(find.byKey(const Key('building-checkbox-1')));
      await tester.pumpAndSettle();
      expect(_buildingCheckbox(tester, 1).value, isTrue);

      // ...and tapping a fully-selected one clears it.
      await tester.tap(find.byKey(const Key('building-checkbox-1')));
      await tester.pumpAndSettle();
      expect(_buildingCheckbox(tester, 1).value, isFalse);
      expect(find.text('0 rooms selected'), findsOneWidget);
    },
  );

  testWidgets('Apply keeps the selection; Clear selection empties it', (
    tester,
  ) async {
    final backend = _mockBackend();
    await _pumpPage(tester, backend.client);

    await _selectTag(tester, 'Emergency');
    await tester.tap(find.byKey(const Key('building-checkbox-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(backend.applied, hasLength(1));
    expect((backend.applied.single['room_ids'] as List).toSet(), {1, 2});

    // Selection deliberately survives an apply — only Clear selection empties it.
    expect(find.text('2 rooms selected'), findsOneWidget);
    expect(_buildingCheckbox(tester, 1).value, isTrue);

    // Let the confirmation SnackBar time out: while showing, it floats over the bottom
    // action bar and would swallow the Clear selection tap below.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // The refetch after applying refreshed the chips: Room 1 gained "Emergency", and
    // Room 2 kept "Surgery" alongside it (the apply is additive).
    await _expandBuilding(tester, 'North Wing');
    expect(find.widgetWithText(Chip, 'Emergency'), findsNWidgets(2));
    expect(find.widgetWithText(Chip, 'Surgery'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Clear selection'));
    await tester.pumpAndSettle();

    expect(find.text('0 rooms selected'), findsOneWidget);
    expect(_buildingCheckbox(tester, 1).value, isFalse);
    expect(_roomCheckbox(tester, 1).value, isFalse);
  });

  testWidgets('Apply is disabled until both a tag and rooms are chosen', (
    tester,
  ) async {
    await _pumpPage(tester, _mockBackend().client);

    Finder apply() => find.widgetWithText(FilledButton, 'Apply');
    expect(tester.widget<FilledButton>(apply()).onPressed, isNull);

    await _selectTag(tester, 'Emergency');
    expect(tester.widget<FilledButton>(apply()).onPressed, isNull);

    await tester.tap(find.byKey(const Key('building-checkbox-2')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(apply()).onPressed, isNotNull);
  });

  testWidgets('search modes filter, clear the query and toggle expansion', (
    tester,
  ) async {
    await _pumpPage(tester, _mockBackend().client);

    // Building mode (the default) starts collapsed and matches building names.
    expect(find.text('Room 1'), findsNothing);
    await tester.enterText(find.byKey(const Key('search-field')), 'south');
    await tester.pumpAndSettle();
    expect(find.text('South Wing'), findsOneWidget);
    expect(find.text('North Wing'), findsNothing);

    // Switching mode clears the query and expands every building.
    await _selectMode(tester, 'Room');
    expect(find.text('North Wing'), findsOneWidget);
    expect(find.text('Room 1'), findsOneWidget);
    expect(find.text('Room 3'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search-field')), 'room 3');
    await tester.pumpAndSettle();
    // Only South Wing has a match, so North Wing disappears entirely.
    expect(find.text('South Wing'), findsOneWidget);
    expect(find.text('North Wing'), findsNothing);
    expect(find.text('Room 3'), findsOneWidget);

    // Tag mode matches rooms by their *attached* tags.
    await _selectMode(tester, 'Tag');
    await tester.enterText(find.byKey(const Key('search-field')), 'surg');
    await tester.pumpAndSettle();
    expect(find.text('North Wing'), findsOneWidget);
    expect(find.text('Room 2'), findsOneWidget);
    expect(find.text('Room 1'), findsNothing);
    expect(find.text('South Wing'), findsNothing);

    // Back to Building mode: query cleared, everything collapsed again.
    await _selectMode(tester, 'Building');
    expect(find.text('North Wing'), findsOneWidget);
    expect(find.text('South Wing'), findsOneWidget);
    expect(find.text('Room 1'), findsNothing);
    expect(find.text('Room 2'), findsNothing);
  });

  testWidgets(
    'a building checkbox only selects rooms visible under the search',
    (tester) async {
      await _pumpPage(tester, _mockBackend().client);

      await _selectMode(tester, 'Room');
      await tester.enterText(find.byKey(const Key('search-field')), 'room 1');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('building-checkbox-1')));
      await tester.pumpAndSettle();

      // Room 2 is filtered out, so tapping North Wing must not have selected it.
      expect(find.text('1 room selected'), findsOneWidget);
      expect(_buildingCheckbox(tester, 1).value, isTrue);
      expect(_roomCheckbox(tester, 1).value, isTrue);
    },
  );
}
