import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/connection/connection_info.dart';
import 'package:app/features/buildings/buildings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient _api(MockClient client) =>
    ApiClient(ConnectionInfo(host: 'test', port: 1234), httpClient: client);

void main() {
  testWidgets('lists buildings with formatted opening/closing times', (
    tester,
  ) async {
    final buildings = [
      {
        'id': 1,
        'name': 'Hospital',
        'opening_minutes': 480,
        'closing_minutes': 1080,
      },
    ];

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/buildings') {
          return http.Response(jsonEncode(buildings), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: BuildingsPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Hospital'), findsOneWidget);
    expect(find.text('08:00 - 18:00'), findsOneWidget);
  });

  testWidgets('creates a new building with the default hours', (
    tester,
  ) async {
    var buildings = <Map<String, dynamic>>[];
    Map<String, dynamic>? createBody;

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/buildings') {
          return http.Response(jsonEncode(buildings), 200);
        }
        if (request.method == 'POST' && request.url.path == '/buildings') {
          createBody = jsonDecode(request.body) as Map<String, dynamic>;
          final created = {'id': 1, ...createBody!};
          buildings = [...buildings, created];
          return http.Response(jsonEncode(created), 201);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: BuildingsPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('No buildings yet.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('New Building'), findsOneWidget);
    // Opening/closing default to 08:00/16:00 without touching the time pickers.
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('16:00'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hospital');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(createBody, {
      'name': 'Hospital',
      'opening_minutes': 480,
      'closing_minutes': 960,
    });
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Hospital'), findsOneWidget);
    expect(find.text('08:00 - 16:00'), findsOneWidget);
  });

  testWidgets('rejects an empty name', (tester) async {
    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/buildings') {
          return http.Response(jsonEncode(<Object>[]), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: BuildingsPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('deletes a building after confirmation', (tester) async {
    var buildings = [
      {
        'id': 1,
        'name': 'Hospital',
        'opening_minutes': 480,
        'closing_minutes': 1080,
      },
    ];
    var deleteRequested = false;

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/buildings') {
          return http.Response(jsonEncode(buildings), 200);
        }
        if (request.method == 'DELETE' && request.url.path == '/buildings/1') {
          deleteRequested = true;
          buildings = [];
          return http.Response('', 204);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: BuildingsPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete building "Hospital"?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(deleteRequested, isTrue);
    expect(find.text('No buildings yet.'), findsOneWidget);
  });

  testWidgets('shows an error snackbar when delete fails', (tester) async {
    final buildings = [
      {
        'id': 1,
        'name': 'Hospital',
        'opening_minutes': 480,
        'closing_minutes': 1080,
      },
    ];

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/buildings') {
          return http.Response(jsonEncode(buildings), 200);
        }
        if (request.method == 'DELETE' && request.url.path == '/buildings/1') {
          return http.Response(
            jsonEncode({
              'detail':
                  'Cannot delete a Building that still has Rooms or Rules attached',
            }),
            409,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: BuildingsPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Could not delete building: Cannot delete a Building that still has Rooms or Rules attached',
      ),
      findsOneWidget,
    );
    expect(find.text('Hospital'), findsOneWidget);
  });
}
