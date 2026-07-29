import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/connection/connection_info.dart';
import 'package:app/features/rules/rules_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Covers RulesPage's own list/create/delete wiring — not RuleFormPage's own field logic
/// (rule_form_page_test.dart already covers that). Rules have no edit flow (see rules_page.dart).
ApiClient _api(MockClient client) =>
    ApiClient(ConnectionInfo(host: 'test', port: 1234), httpClient: client);

const _roles = [
  {'id': 1, 'name': 'Senior Fellow'},
];
const _buildings = [
  {
    'id': 1,
    'name': 'Hospital',
    'opening_minutes': 480,
    'closing_minutes': 1080,
  },
];
const _tags = [
  {'id': 1, 'name': 'Emergency Department'},
];

void main() {
  testWidgets('lists rules with role, target and minimum count', (
    tester,
  ) async {
    final rules = [
      {
        'id': 1,
        'name': 'ED coverage',
        'rule_type': 'minimum_count',
        'role_id': 1,
        'building_id': 1,
        'tag_id': null,
        'minimum_count': 2,
      },
      {
        'id': 2,
        'name': 'ED eligibility',
        'rule_type': 'eligibility_restriction',
        'role_id': 1,
        'building_id': null,
        'tag_id': 1,
        'minimum_count': null,
      },
    ];

    final api = _api(
      MockClient((request) async {
        if (request.url.path == '/rules') {
          return http.Response(jsonEncode(rules), 200);
        }
        if (request.url.path == '/roles') {
          return http.Response(jsonEncode(_roles), 200);
        }
        if (request.url.path == '/buildings') {
          return http.Response(jsonEncode(_buildings), 200);
        }
        if (request.url.path == '/tags') {
          return http.Response(jsonEncode(_tags), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: RulesPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('ED coverage'), findsOneWidget);
    expect(
      find.text(
        'Minimum count · Role: Senior Fellow · Building: Hospital · Min: 2',
      ),
      findsOneWidget,
    );
    expect(find.text('ED eligibility'), findsOneWidget);
    expect(
      find.text(
        'Eligibility restriction · Role: Senior Fellow · Tag: Emergency Department',
      ),
      findsOneWidget,
    );
  });

  testWidgets('creates a new rule with the defaulted fields and reloads', (
    tester,
  ) async {
    var rules = <Map<String, dynamic>>[];
    Map<String, dynamic>? createBody;

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/rules') {
          return http.Response(jsonEncode(rules), 200);
        }
        if (request.url.path == '/roles') {
          return http.Response(jsonEncode(_roles), 200);
        }
        if (request.url.path == '/buildings') {
          return http.Response(jsonEncode(_buildings), 200);
        }
        if (request.url.path == '/tags') {
          return http.Response(jsonEncode(_tags), 200);
        }
        if (request.method == 'POST' && request.url.path == '/rules') {
          createBody = jsonDecode(request.body) as Map<String, dynamic>;
          final created = {'id': 1, ...createBody!};
          rules = [...rules, created];
          return http.Response(jsonEncode(created), 201);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: RulesPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('No rules yet.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('New Rule'), findsOneWidget);

    // Rule type/role/building/minimum-count all default to something valid — only the name
    // needs filling in.
    await tester.enterText(find.byType(TextField).first, 'ED coverage');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(createBody, {
      'name': 'ED coverage',
      'rule_type': 'minimum_count',
      'role_id': 1,
      'building_id': 1,
      'tag_id': null,
      'minimum_count': 1,
    });
    expect(find.text('New Rule'), findsNothing);
    expect(find.text('ED coverage'), findsOneWidget);
  });

  testWidgets('deletes a rule after confirmation', (tester) async {
    var rules = [
      {
        'id': 1,
        'name': 'ED coverage',
        'rule_type': 'minimum_count',
        'role_id': 1,
        'building_id': 1,
        'tag_id': null,
        'minimum_count': 2,
      },
    ];
    var deleteRequested = false;

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/rules') {
          return http.Response(jsonEncode(rules), 200);
        }
        if (request.url.path == '/roles') {
          return http.Response(jsonEncode(_roles), 200);
        }
        if (request.url.path == '/buildings') {
          return http.Response(jsonEncode(_buildings), 200);
        }
        if (request.url.path == '/tags') {
          return http.Response(jsonEncode(_tags), 200);
        }
        if (request.method == 'DELETE' && request.url.path == '/rules/1') {
          deleteRequested = true;
          rules = [];
          return http.Response('', 204);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: RulesPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete rule "ED coverage"?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(deleteRequested, isTrue);
    expect(find.text('No rules yet.'), findsOneWidget);
  });

  testWidgets(
    'shows the fixed error message when delete fails on violation history',
    (tester) async {
      final rules = [
        {
          'id': 1,
          'name': 'ED coverage',
          'rule_type': 'minimum_count',
          'role_id': 1,
          'building_id': 1,
          'tag_id': null,
          'minimum_count': 2,
        },
      ];

      final api = _api(
        MockClient((request) async {
          if (request.method == 'GET' && request.url.path == '/rules') {
            return http.Response(jsonEncode(rules), 200);
          }
          if (request.url.path == '/roles') {
            return http.Response(jsonEncode(_roles), 200);
          }
          if (request.url.path == '/buildings') {
            return http.Response(jsonEncode(_buildings), 200);
          }
          if (request.url.path == '/tags') {
            return http.Response(jsonEncode(_tags), 200);
          }
          if (request.method == 'DELETE' && request.url.path == '/rules/1') {
            return http.Response(
              jsonEncode({'detail': 'Cannot delete a Rule'}),
              409,
            );
          }
          return http.Response('not found', 404);
        }),
      );

      await tester.pumpWidget(MaterialApp(home: RulesPage(api: api)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not delete rule — it may be referenced by past roster violation history',
        ),
        findsOneWidget,
      );
      expect(find.text('ED coverage'), findsOneWidget);
    },
  );
}
