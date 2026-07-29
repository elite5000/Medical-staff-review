import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/connection/connection_info.dart';
import 'package:app/features/rooms/rooms_page.dart';
import 'package:app/features/tags/tags_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Covers the shared BulkAddDialog through two of its four hosts: Tags (the name-only case,
/// where already-existing names come back as `skipped`) and Rooms (the only one with a
/// building picker). Roles behaves exactly as Tags does, and Staff exactly as Rooms does
/// minus the picker, so both are exercised by these two.
///
/// Kept out of tags_page_test.dart/a rooms_page_test.dart deliberately: it tests the dialog,
/// not either list page's own CRUD.
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

void main() {
  testWidgets('bulk-adds pasted tags, reporting created and skipped', (
    tester,
  ) async {
    var tags = <Map<String, dynamic>>[
      {'id': 1, 'name': 'General Practice'},
    ];
    Map<String, dynamic>? bulkBody;

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/tags') {
          return http.Response(jsonEncode(tags), 200);
        }
        if (request.method == 'POST' && request.url.path == '/tags/bulk') {
          bulkBody = jsonDecode(request.body) as Map<String, dynamic>;
          final created = [
            {'id': 2, 'name': 'Surgery'},
            {'id': 3, 'name': 'Emergency Department'},
          ];
          tags = [...tags, ...created];
          return http.Response(
            jsonEncode({
              'created': created,
              'skipped': ['General Practice'],
            }),
            201,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: TagsPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.playlist_add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      // Blank and padded lines are what a real paste out of a spreadsheet looks like.
      'Surgery\n\n  Emergency Department  \nGeneral Practice\n',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // Split on newlines, trimmed, blanks dropped — before the request goes out.
    expect(bulkBody?['names'], [
      'Surgery',
      'Emergency Department',
      'General Practice',
    ]);
    // The dialog closed and the page reloaded through AsyncLoader.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Surgery'), findsOneWidget);
    expect(find.text('Emergency Department'), findsOneWidget);
    expect(
      find.text('Added 2 tags. 1 already existed: General Practice.'),
      findsOneWidget,
    );
  });

  testWidgets('bulk add rejects a paste with no usable names', (tester) async {
    var postedBulk = false;
    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/tags') {
          return http.Response(jsonEncode(<Map<String, dynamic>>[]), 200);
        }
        if (request.url.path == '/tags/bulk') {
          postedBulk = true;
          return http.Response(jsonEncode({'created': [], 'skipped': []}), 201);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: TagsPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.playlist_add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '\n   \n\n');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(postedBulk, isFalse);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Enter at least one name'), findsOneWidget);
  });

  testWidgets('bulk-adds pasted rooms under the picked building', (
    tester,
  ) async {
    var rooms = <Map<String, dynamic>>[];
    Map<String, dynamic>? bulkBody;

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/rooms') {
          return http.Response(jsonEncode(rooms), 200);
        }
        if (request.method == 'GET' && request.url.path == '/buildings') {
          return http.Response(jsonEncode(_buildings), 200);
        }
        if (request.method == 'POST' && request.url.path == '/rooms/bulk') {
          bulkBody = jsonDecode(request.body) as Map<String, dynamic>;
          final created = [
            {
              'id': 1,
              'name': 'Room 1',
              'building_id': bulkBody!['building_id'],
              'tags': <Map<String, dynamic>>[],
            },
            {
              'id': 2,
              'name': 'Room 2',
              'building_id': bulkBody!['building_id'],
              'tags': <Map<String, dynamic>>[],
            },
          ];
          rooms = [...rooms, ...created];
          return http.Response(
            jsonEncode({'created': created, 'skipped': <String>[]}),
            201,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: RoomsPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.playlist_add));
    await tester.pumpAndSettle();

    // Rooms is the only bulk-add with a building picker; it defaults to the first building,
    // so switching to the second proves the choice is what reaches the request.
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annexe').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Room 1\n\n  Room 2  \n');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(bulkBody, {
      'building_id': 2,
      'names': ['Room 1', 'Room 2'],
    });
    expect(find.byType(AlertDialog), findsNothing);
    // Reloaded through AsyncLoader; each row's subtitle names the building it landed in.
    expect(find.text('Room 1'), findsOneWidget);
    expect(find.text('Annexe'), findsNWidgets(2));
    expect(find.text('Added 2 rooms.'), findsOneWidget);
  });

  testWidgets('bulk add blocks when there are no buildings to add rooms to', (
    tester,
  ) async {
    final api = _api(
      MockClient((request) async {
        if (request.url.path == '/rooms' || request.url.path == '/buildings') {
          return http.Response(jsonEncode(<Map<String, dynamic>>[]), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: RoomsPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.playlist_add));
    await tester.pumpAndSettle();

    expect(
      find.text('Add a building first — every room belongs to one.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add'))
          .onPressed,
      isNull,
    );
  });
}
