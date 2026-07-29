import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/connection/connection_info.dart';
import 'package:app/features/roles/roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('lists roles and creates a new one', (tester) async {
    var roles = <Map<String, dynamic>>[
      {'id': 1, 'name': 'Senior Fellow'},
    ];

    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/roles') {
        return http.Response(jsonEncode(roles), 200);
      }
      if (request.method == 'POST' && request.url.path == '/roles') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final created = {'id': 2, 'name': body['name']};
        roles = [...roles, created];
        return http.Response(jsonEncode(created), 201);
      }
      return http.Response('not found', 404);
    });

    final api = ApiClient(
      ConnectionInfo(host: 'test', port: 1234),
      httpClient: client,
    );

    await tester.pumpWidget(MaterialApp(home: RolesPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Senior Fellow'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nurse Practitioner');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Nurse Practitioner'), findsOneWidget);
  });
}
