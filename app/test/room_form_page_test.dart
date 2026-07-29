import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/api/models.dart';
import 'package:app/connection/connection_info.dart';
import 'package:app/features/rooms/room_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient _api(MockClient client) =>
    ApiClient(ConnectionInfo(host: 'test', port: 1234), httpClient: client);

const _buildings = [
  {
    'id': 1,
    'name': 'Hospital',
    'opening_minutes': 480,
    'closing_minutes': 1080,
  },
  {'id': 2, 'name': 'Annexe', 'opening_minutes': 480, 'closing_minutes': 1080},
];

const _tags = [
  {'id': 1, 'name': 'Surgery'},
  {'id': 2, 'name': 'General Practice'},
];

void main() {
  testWidgets('rejects an empty name', (tester) async {
    final api = _api(
      MockClient((request) async {
        if (request.url.path == '/buildings') {
          return http.Response(jsonEncode(_buildings), 200);
        }
        if (request.url.path == '/tags') {
          return http.Response(jsonEncode(_tags), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: RoomFormPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
  });

  testWidgets('requires a building when none exist', (tester) async {
    final api = _api(
      MockClient((request) async {
        if (request.url.path == '/buildings') {
          return http.Response(jsonEncode(<Object>[]), 200);
        }
        if (request.url.path == '/tags') {
          return http.Response(jsonEncode(_tags), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: RoomFormPage(api: api)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Room 1');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('A building is required'), findsOneWidget);
  });

  testWidgets('creates a room in the picked building with selected tags', (
    tester,
  ) async {
    Map<String, dynamic>? createBody;

    final api = _api(
      MockClient((request) async {
        if (request.url.path == '/buildings') {
          return http.Response(jsonEncode(_buildings), 200);
        }
        if (request.url.path == '/tags') {
          return http.Response(jsonEncode(_tags), 200);
        }
        if (request.method == 'POST' && request.url.path == '/rooms') {
          createBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 1,
              'name': createBody!['name'],
              'building_id': createBody!['building_id'],
              'tags': _tags.where(
                (t) => (createBody!['tag_ids'] as List).contains(t['id']),
              ),
            }),
            201,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: RoomFormPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('New Room'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Room 1');

    // Building defaults to the first one loaded; switch to the second.
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annexe').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Surgery'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(createBody, {
      'name': 'Room 1',
      'building_id': 2,
      'tag_ids': [1],
    });
  });

  testWidgets('pre-fills an existing room and submits an update', (
    tester,
  ) async {
    final existing = Room(
      id: 5,
      name: 'Room 1',
      buildingId: 1,
      tags: [Tag(id: 1, name: 'Surgery')],
    );
    Map<String, dynamic>? patchBody;

    final api = _api(
      MockClient((request) async {
        if (request.url.path == '/buildings') {
          return http.Response(jsonEncode(_buildings), 200);
        }
        if (request.url.path == '/tags') {
          return http.Response(jsonEncode(_tags), 200);
        }
        if (request.method == 'PATCH' && request.url.path == '/rooms/5') {
          patchBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 5,
              'name': patchBody!['name'],
              'building_id': patchBody!['building_id'],
              'tags': _tags.where(
                (t) => (patchBody!['tag_ids'] as List).contains(t['id']),
              ),
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RoomFormPage(api: api, existing: existing),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Room'), findsOneWidget);
    // Name is pre-filled and the existing tag starts checked.
    expect(find.text('Room 1'), findsOneWidget);
    final surgeryCheckbox = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Surgery'),
    );
    expect(surgeryCheckbox.value, isTrue);

    // Add the second tag on top of the pre-selected one.
    await tester.tap(find.widgetWithText(CheckboxListTile, 'General Practice'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(patchBody!['name'], 'Room 1');
    expect(patchBody!['building_id'], 1);
    expect(Set<int>.from(patchBody!['tag_ids'] as List), {1, 2});
  });
}
