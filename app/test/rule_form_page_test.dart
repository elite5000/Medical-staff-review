import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/api/models.dart';
import 'package:app/connection/connection_info.dart';
import 'package:app/features/rules/rule_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  ApiClient buildApi() {
    final client = MockClient((request) async {
      if (request.url.path == '/roles') {
        return http.Response(
          jsonEncode([
            {'id': 1, 'name': 'Senior Fellow'},
          ]),
          200,
        );
      }
      if (request.url.path == '/buildings') {
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'name': 'Main Building',
              'opening_minutes': 480,
              'closing_minutes': 1020,
            },
          ]),
          200,
        );
      }
      if (request.url.path == '/tags') {
        return http.Response(
          jsonEncode([
            {'id': 1, 'name': 'Emergency Department'},
          ]),
          200,
        );
      }
      return http.Response('not found', 404);
    });
    return ApiClient(
      ConnectionInfo(host: 'test', port: 1234),
      httpClient: client,
    );
  }

  testWidgets(
    'minimum-count rules show target/count fields; eligibility rules do not',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: RuleFormPage(api: buildApi())));
      await tester.pumpAndSettle();

      // Default rule type is minimum_count.
      expect(find.text('Applies to'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Minimum count'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<RuleType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eligibility restriction').last);
      await tester.pumpAndSettle();

      expect(find.text('Applies to'), findsNothing);
      expect(find.widgetWithText(TextField, 'Minimum count'), findsNothing);
      expect(find.text('Tag'), findsOneWidget);
    },
  );
}
