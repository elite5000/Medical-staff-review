import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/connection/connection_info.dart';
import 'package:app/features/rooms/rooms_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Covers RoomsPage's own list/CRUD wiring — not the bulk-add dialog, which
/// bulk_add_dialog_test.dart already exercises through this same page.
ApiClient _api(MockClient client) =>
    ApiClient(ConnectionInfo(host: 'test', port: 1234), httpClient: client);

const _buildings = [
  {
    'id': 1,
    'name': 'Hospital',
    'opening_minutes': 480,
    'closing_minutes': 1080,
  },
];

const _tags = [
  {'id': 1, 'name': 'Surgery'},
];

void main() {
  testWidgets('lists rooms with their building and tags', (tester) async {
    final rooms = [
      {
        'id': 1,
        'name': 'Room 1',
        'building_id': 1,
        'tags': [
          {'id': 1, 'name': 'Surgery'},
        ],
      },
      {'id': 2, 'name': 'Room 2', 'building_id': 1, 'tags': <Object>[]},
    ];

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/rooms') {
          return http.Response(jsonEncode(rooms), 200);
        }
        if (request.method == 'GET' && request.url.path == '/buildings') {
          return http.Response(jsonEncode(_buildings), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: RoomsPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Room 1'), findsOneWidget);
    // Tagged room shows "Building · Tag"; untagged room falls back to just the building.
    expect(find.text('Hospital · Surgery'), findsOneWidget);
    expect(find.text('Hospital'), findsOneWidget);
  });

  testWidgets('creates a new room via the New Room page', (tester) async {
    var rooms = <Map<String, dynamic>>[];

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/rooms') {
          return http.Response(jsonEncode(rooms), 200);
        }
        if (request.method == 'GET' && request.url.path == '/buildings') {
          return http.Response(jsonEncode(_buildings), 200);
        }
        if (request.method == 'GET' && request.url.path == '/tags') {
          return http.Response(jsonEncode(_tags), 200);
        }
        if (request.method == 'POST' && request.url.path == '/rooms') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final created = {
            'id': 1,
            'name': body['name'],
            'building_id': body['building_id'],
            'tags': <Object>[],
          };
          rooms = [...rooms, created];
          return http.Response(jsonEncode(created), 201);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: RoomsPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('No rooms yet.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('New Room'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Room 1');
    // The building dropdown defaults to the only building loaded, so Save can be tapped
    // straight away.
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Back on the list, reloaded with the newly created room.
    expect(find.text('New Room'), findsNothing);
    expect(find.text('Room 1'), findsOneWidget);
    expect(find.text('Hospital'), findsOneWidget);
  });

  testWidgets('deletes a room after confirmation', (tester) async {
    var rooms = [
      {'id': 1, 'name': 'Room 1', 'building_id': 1, 'tags': <Object>[]},
    ];
    var deleteRequested = false;

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/rooms') {
          return http.Response(jsonEncode(rooms), 200);
        }
        if (request.method == 'GET' && request.url.path == '/buildings') {
          return http.Response(jsonEncode(_buildings), 200);
        }
        if (request.method == 'DELETE' && request.url.path == '/rooms/1') {
          deleteRequested = true;
          rooms = [];
          return http.Response('', 204);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: RoomsPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete room "Room 1"?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(deleteRequested, isTrue);
    expect(find.text('No rooms yet.'), findsOneWidget);
  });

  testWidgets('shows an error snackbar when delete fails', (tester) async {
    final rooms = [
      {'id': 1, 'name': 'Room 1', 'building_id': 1, 'tags': <Object>[]},
    ];

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/rooms') {
          return http.Response(jsonEncode(rooms), 200);
        }
        if (request.method == 'GET' && request.url.path == '/buildings') {
          return http.Response(jsonEncode(_buildings), 200);
        }
        if (request.method == 'DELETE' && request.url.path == '/rooms/1') {
          return http.Response(
            jsonEncode({
              'detail': 'Cannot delete a Room that appears in a generated Roster',
            }),
            409,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: RoomsPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Could not delete room: Cannot delete a Room that appears in a generated Roster',
      ),
      findsOneWidget,
    );
    // The room stays listed — the delete never actually went through.
    expect(find.text('Room 1'), findsOneWidget);
  });
}
