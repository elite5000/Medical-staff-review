import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/connection/connection_info.dart';
import 'package:app/features/rosters/rosters_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('only the latest generation of a date range offers Regenerate', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/rosters') {
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'start_date': '2026-08-03',
              'end_date': '2026-08-16',
              'generated_at': '2026-08-01T09:00:00',
              'generated_from_roster_id': null,
              'has_violations': false,
            },
            {
              'id': 2,
              'start_date': '2026-08-03',
              'end_date': '2026-08-16',
              'generated_at': '2026-08-02T09:00:00',
              'generated_from_roster_id': 1,
              'has_violations': false,
            },
          ]),
          200,
        );
      }
      return http.Response('not found', 404);
    });
    final api = ApiClient(
      ConnectionInfo(host: 'test', port: 1234),
      httpClient: client,
    );

    await tester.pumpWidget(MaterialApp(home: RostersPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Regenerate'), findsOneWidget);
  });
}
