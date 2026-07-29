import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/connection/connection_info.dart';
import 'package:app/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient _api(MockClient client) =>
    ApiClient(ConnectionInfo(host: 'test', port: 1234), httpClient: client);

const _settingsJson = {
  'shift_length_minutes': 240,
  'travel_time_minutes': 15,
  'max_daily_minutes': 480,
};

void main() {
  testWidgets('populates fields from the loaded settings', (tester) async {
    final api = _api(
      MockClient((request) async {
        if (request.url.path == '/settings') {
          return http.Response(jsonEncode(_settingsJson), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(api: api, onDisconnect: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, 'Shift length (minutes)'),
      findsOneWidget,
    );
    final shiftField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Shift length (minutes)'),
    );
    expect(shiftField.controller!.text, '240');
  });

  testWidgets('saves valid settings and shows Saved.', (tester) async {
    Map<String, dynamic>? patchBody;

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/settings') {
          return http.Response(jsonEncode(_settingsJson), 200);
        }
        if (request.method == 'PATCH' && request.url.path == '/settings') {
          patchBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({..._settingsJson, ...patchBody!}),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(api: api, onDisconnect: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Shift length (minutes)'),
      '300',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(patchBody, {
      'shift_length_minutes': 300,
      'travel_time_minutes': 15,
      'max_daily_minutes': 480,
    });
    expect(find.text('Saved.'), findsOneWidget);
  });

  testWidgets('rejects a non-positive shift length without saving', (
    tester,
  ) async {
    var patchRequested = false;

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/settings') {
          return http.Response(jsonEncode(_settingsJson), 200);
        }
        if (request.method == 'PATCH' && request.url.path == '/settings') {
          patchRequested = true;
          return http.Response(jsonEncode(_settingsJson), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(api: api, onDisconnect: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Shift length (minutes)'),
      '0',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Shift length must be a positive number of minutes'),
      findsOneWidget,
    );
    expect(patchRequested, isFalse);
  });

  testWidgets('shows the API error message when save fails', (tester) async {
    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/settings') {
          return http.Response(jsonEncode(_settingsJson), 200);
        }
        if (request.method == 'PATCH' && request.url.path == '/settings') {
          return http.Response(jsonEncode({'detail': 'Server exploded'}), 500);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(api: api, onDisconnect: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Server exploded'), findsOneWidget);
    expect(find.text('Saved.'), findsNothing);
  });

  testWidgets('disconnects only after confirming', (tester) async {
    var disconnected = false;

    final api = _api(
      MockClient((request) async {
        if (request.url.path == '/settings') {
          return http.Response(jsonEncode(_settingsJson), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(api: api, onDisconnect: () => disconnected = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Disconnect'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Disconnect from this backend?'),
      findsOneWidget,
    );

    // Cancelling must not disconnect.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(disconnected, isFalse);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Disconnect'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Disconnect'));
    await tester.pumpAndSettle();

    expect(disconnected, isTrue);
  });
}
