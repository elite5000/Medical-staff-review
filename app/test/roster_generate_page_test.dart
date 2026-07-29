import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/connection/connection_info.dart';
import 'package:app/features/rosters/roster_generate_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient _api(MockClient client) =>
    ApiClient(ConnectionInfo(host: 'test', port: 1234), httpClient: client);

/// Opens the date picker and confirms its default-highlighted date (today), which is all
/// _generate needs — the exact date doesn't matter to these tests.
Future<void> _pickStartDate(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(OutlinedButton, 'Start date'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('requires a start date before generating', (tester) async {
    final api = _api(MockClient((request) async => http.Response('', 404)));

    await tester.pumpWidget(MaterialApp(home: RosterGeneratePage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();

    expect(find.text('A start date is required'), findsOneWidget);
  });

  testWidgets('rejects a number of days outside 1-14', (tester) async {
    final api = _api(MockClient((request) async => http.Response('', 404)));

    await tester.pumpWidget(MaterialApp(home: RosterGeneratePage(api: api)));
    await tester.pumpAndSettle();

    await _pickStartDate(tester);
    await tester.enterText(find.byType(TextField), '15');
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();

    expect(
      find.text('Number of days must be a whole number from 1 to 14'),
      findsOneWidget,
    );
  });

  testWidgets(
    'generates a roster with the picked date and navigates to the roster view',
    (tester) async {
      Map<String, dynamic>? postBody;

      final api = _api(
        MockClient((request) async {
          if (request.method == 'POST' && request.url.path == '/rosters') {
            postBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'id': 1,
                'start_date': postBody!['start_date'],
                'end_date': postBody!['start_date'],
                'generated_at': '2026-01-01T00:00:00',
                'generated_from_roster_id': null,
                'has_violations': false,
              }),
              201,
            );
          }
          if (request.method == 'GET' && request.url.path == '/rosters/1') {
            return http.Response(
              jsonEncode({
                'id': 1,
                'start_date': postBody!['start_date'],
                'end_date': postBody!['start_date'],
                'generated_at': '2026-01-01T00:00:00',
                'generated_from_roster_id': null,
                'has_violations': false,
                'shifts': <Object>[],
                'violations': <Object>[],
              }),
              200,
            );
          }
          if (request.method == 'GET' &&
              [
                '/rooms',
                '/staff',
                '/buildings',
                '/tags',
                '/rosters',
              ].contains(request.url.path)) {
            return http.Response(jsonEncode(<Object>[]), 200);
          }
          return http.Response('not found', 404);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: RosterGeneratePage(api: api)),
      );
      await tester.pumpAndSettle();

      await _pickStartDate(tester);
      // Leave "Number of days" at its default (14).
      await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
      await tester.pumpAndSettle();

      expect(postBody!['num_days'], 14);
      expect(find.text('Generate Roster'), findsNothing);
      // Replaced this page and pushed RosterViewPage on top.
      expect(find.text('Roster'), findsOneWidget);
    },
  );

  testWidgets('shows the API error message and stays on the page', (
    tester,
  ) async {
    final api = _api(
      MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/rosters') {
          return http.Response(
            jsonEncode({'detail': 'No eligible staff for some shifts'}),
            409,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: RosterGeneratePage(api: api)));
    await tester.pumpAndSettle();

    await _pickStartDate(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
    await tester.pumpAndSettle();

    expect(find.text('No eligible staff for some shifts'), findsOneWidget);
    expect(find.text('Generate Roster'), findsOneWidget);
  });
}
