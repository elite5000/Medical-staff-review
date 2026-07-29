import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/connection/connection_info.dart';
import 'package:app/features/staff/staff_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Covers StaffPage's own list/CRUD wiring — not the bulk-add dialog (already covered by
/// bulk_add_dialog_test.dart) nor the create/edit form's own fields (staff_form_page_test.dart).
ApiClient _api(MockClient client) =>
    ApiClient(ConnectionInfo(host: 'test', port: 1234), httpClient: client);

Map<String, dynamic> _staffJson({
  required int id,
  required String name,
  bool active = true,
  List<Map<String, dynamic>> roles = const [],
}) => {
  'id': id,
  'name': name,
  'active': active,
  'roles': roles,
  'preferred_days': <Object>[],
  'unavailabilities': <Object>[],
};

void main() {
  testWidgets('lists staff with active status and roles', (tester) async {
    final staff = [
      _staffJson(
        id: 1,
        name: 'Dr. Alice',
        roles: [
          {'id': 1, 'name': 'Senior Fellow'},
        ],
      ),
      _staffJson(id: 2, name: 'Dr. Bob', active: false),
    ];

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/staff') {
          return http.Response(jsonEncode(staff), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: StaffPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Dr. Alice'), findsOneWidget);
    expect(find.text('Active · Senior Fellow'), findsOneWidget);
    expect(find.text('Dr. Bob'), findsOneWidget);
    expect(find.text('Inactive · '), findsOneWidget);
  });

  testWidgets('opens the New Staff Member form and reloads on return', (
    tester,
  ) async {
    var staffRequests = 0;

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/staff') {
          staffRequests++;
          return http.Response(jsonEncode(<Object>[]), 200);
        }
        if (request.method == 'GET' && request.url.path == '/roles') {
          return http.Response(jsonEncode(<Object>[]), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: StaffPage(api: api)));
    await tester.pumpAndSettle();
    expect(staffRequests, 1);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('New Staff Member'), findsOneWidget);
    // StaffFormPage's own AsyncLoader also fetches /staff (to overlay live-edited
    // unavailability onto the calendar), so opening the form issues a second request.
    expect(staffRequests, 2);

    // StaffFormPage stays open after a save (to allow adding unavailability), so StaffPage
    // always reloads on any return — including a plain back-navigation with nothing saved.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('New Staff Member'), findsNothing);
    expect(staffRequests, 3);
  });

  testWidgets('deletes a staff member after confirmation', (tester) async {
    var staff = [_staffJson(id: 1, name: 'Dr. Alice')];
    var deleteRequested = false;

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/staff') {
          return http.Response(jsonEncode(staff), 200);
        }
        if (request.method == 'DELETE' && request.url.path == '/staff/1') {
          deleteRequested = true;
          staff = [];
          return http.Response('', 204);
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: StaffPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete staff member "Dr. Alice"?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(deleteRequested, isTrue);
    expect(find.text('No staff yet.'), findsOneWidget);
  });

  testWidgets(
    'shows the deactivate-instead message when delete fails because of roster history',
    (tester) async {
      final staff = [_staffJson(id: 1, name: 'Dr. Alice')];

      final api = _api(
        MockClient((request) async {
          if (request.method == 'GET' && request.url.path == '/staff') {
            return http.Response(jsonEncode(staff), 200);
          }
          if (request.method == 'DELETE' && request.url.path == '/staff/1') {
            return http.Response(
              jsonEncode({
                'detail':
                    'Cannot delete Staff who appear in a generated Roster — deactivate instead',
              }),
              409,
            );
          }
          return http.Response('not found', 404);
        }),
      );

      await tester.pumpWidget(MaterialApp(home: StaffPage(api: api)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not delete staff member who appears in a generated roster — deactivate instead',
        ),
        findsOneWidget,
      );
      expect(find.text('Dr. Alice'), findsOneWidget);
    },
  );
}
