import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/connection/connection_info.dart';
import 'package:app/features/roles/bulk_apply_role_page.dart';
import 'package:app/features/roles/roles_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _staff(
  int id,
  String name, {
  bool active = true,
  List<Map<String, dynamic>> roles = const [],
}) => {
  'id': id,
  'name': name,
  'active': active,
  'roles': roles,
  'preferred_days': <Map<String, dynamic>>[],
  'unavailabilities': <Map<String, dynamic>>[],
};

const _seniorFellow = {'id': 1, 'name': 'Senior Fellow'};
const _nurse = {'id': 2, 'name': 'Nurse Practitioner'};

/// Backs the page with an in-memory store whose /roles/{id}/apply-to-staff is additive and
/// idempotent, like the real endpoint. [applyBodies] records every apply request body.
ApiClient _api({
  required List<Map<String, dynamic>> staff,
  required List<Map<String, dynamic>> applyBodies,
}) {
  final client = MockClient((request) async {
    if (request.method == 'GET' && request.url.path == '/roles') {
      return http.Response(jsonEncode([_seniorFellow, _nurse]), 200);
    }
    if (request.method == 'GET' && request.url.path == '/staff') {
      return http.Response(jsonEncode(staff), 200);
    }
    if (request.method == 'POST' &&
        request.url.path == '/roles/1/apply-to-staff') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      applyBodies.add(body);
      final ids = (body['staff_ids'] as List).cast<int>().toSet();
      final updated = <Map<String, dynamic>>[];
      for (var i = 0; i < staff.length; i++) {
        if (!ids.contains(staff[i]['id'])) continue;
        final roles = (staff[i]['roles'] as List).cast<Map<String, dynamic>>();
        if (!roles.any((r) => r['id'] == 1)) {
          staff[i] = {
            ...staff[i],
            'roles': [...roles, _seniorFellow],
          };
        }
        updated.add(staff[i]);
      }
      return http.Response(jsonEncode(updated), 200);
    }
    return http.Response('not found', 404);
  });
  return ApiClient(
    ConnectionInfo(host: 'test', port: 1234),
    httpClient: client,
  );
}

CheckboxListTile _tileFor(WidgetTester tester, String name) => tester.widget(
  find.ancestor(of: find.text(name), matching: find.byType(CheckboxListTile)),
);

void main() {
  testWidgets('selects and deselects staff via checkboxes', (tester) async {
    final staff = [
      _staff(10, 'Dr. Alice'),
      _staff(11, 'Dr. Bob', active: false),
    ];
    final api = _api(staff: staff, applyBodies: []);

    await tester.pumpWidget(MaterialApp(home: BulkApplyRolePage(api: api)));
    await tester.pumpAndSettle();

    expect(_tileFor(tester, 'Dr. Alice').value, isFalse);
    expect(find.text('Inactive'), findsOneWidget);

    await tester.tap(find.text('Dr. Alice'));
    await tester.pump();
    expect(_tileFor(tester, 'Dr. Alice').value, isTrue);
    expect(_tileFor(tester, 'Dr. Bob').value, isFalse);
    expect(find.text('Apply to 1 selected'), findsOneWidget);

    await tester.tap(find.text('Dr. Alice'));
    await tester.pump();
    expect(_tileFor(tester, 'Dr. Alice').value, isFalse);
    expect(find.text('Apply to 0 selected'), findsOneWidget);
  });

  testWidgets('filters the staff list by name, case-insensitively', (
    tester,
  ) async {
    final staff = [
      _staff(10, 'Dr. Alice'),
      _staff(11, 'Dr. Bob'),
      _staff(12, 'Nurse Alicia'),
    ];
    final api = _api(staff: staff, applyBodies: []);

    await tester.pumpWidget(MaterialApp(home: BulkApplyRolePage(api: api)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'alic');
    await tester.pumpAndSettle();

    expect(find.text('Dr. Alice'), findsOneWidget);
    expect(find.text('Nurse Alicia'), findsOneWidget);
    expect(find.text('Dr. Bob'), findsNothing);

    // Filtering is a view concern only — a hidden staff member stays selected.
    await tester.tap(find.text('Dr. Alice'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'bob');
    await tester.pumpAndSettle();
    expect(find.text('Dr. Alice'), findsNothing);
    expect(find.text('Apply to 1 selected'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No staff match "zzz".'), findsOneWidget);
  });

  testWidgets('apply keeps the selection and refreshes role chips', (
    tester,
  ) async {
    final staff = [
      _staff(10, 'Dr. Alice', roles: [_nurse]),
      _staff(11, 'Dr. Bob'),
    ];
    final applyBodies = <Map<String, dynamic>>[];
    final api = _api(staff: staff, applyBodies: applyBodies);

    await tester.pumpWidget(MaterialApp(home: BulkApplyRolePage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dr. Alice'));
    await tester.tap(find.text('Dr. Bob'));
    await tester.pump();
    expect(find.text('Apply to 2 selected'), findsOneWidget);

    await tester.tap(find.text('Apply to 2 selected'));
    await tester.pumpAndSettle();

    expect(applyBodies, [
      {
        'staff_ids': [10, 11],
      },
    ]);
    // Additive: Alice keeps Nurse Practitioner and gains Senior Fellow.
    expect(find.widgetWithText(Chip, 'Nurse Practitioner'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Senior Fellow'), findsNWidgets(2));
    // The whole point of the separate Clear control: Apply must not clear the selection.
    expect(_tileFor(tester, 'Dr. Alice').value, isTrue);
    expect(_tileFor(tester, 'Dr. Bob').value, isTrue);
    expect(find.text('Apply to 2 selected'), findsOneWidget);

    // Let the success SnackBar time out — until it does it sits over the button row and
    // would swallow the tap below.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear selection'));
    await tester.pump();

    expect(_tileFor(tester, 'Dr. Alice').value, isFalse);
    expect(_tileFor(tester, 'Dr. Bob').value, isFalse);
    expect(find.text('Apply to 0 selected'), findsOneWidget);
  });

  testWidgets('RolesPage opens the page from its "Apply to staff" action', (
    tester,
  ) async {
    final api = _api(staff: [_staff(10, 'Dr. Alice')], applyBodies: []);

    await tester.pumpWidget(MaterialApp(home: RolesPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.group_add));
    await tester.pumpAndSettle();

    expect(find.byType(BulkApplyRolePage), findsOneWidget);
    expect(find.text('Dr. Alice'), findsOneWidget);
  });
}
