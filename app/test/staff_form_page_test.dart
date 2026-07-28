import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/connection/connection_info.dart';
import 'package:app/features/staff/staff_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('toggles preferred days independently per week', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/roles') {
        return http.Response(jsonEncode([]), 200);
      }
      if (request.url.path == '/staff') {
        return http.Response(jsonEncode([]), 200);
      }
      return http.Response('not found', 404);
    });
    final api = ApiClient(
      ConnectionInfo(host: 'test', port: 1234),
      httpClient: client,
    );

    await tester.pumpWidget(MaterialApp(home: StaffFormPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Preferred days — Week 1'), findsOneWidget);
    expect(find.text('Preferred days — Week 2'), findsOneWidget);

    // Two 'Mon' chips exist (one per week) — selecting week 1's must not affect week 2's.
    final mondayChips = find.widgetWithText(FilterChip, 'Mon');
    expect(mondayChips, findsNWidgets(2));

    await tester.tap(mondayChips.first);
    await tester.pump();

    final week1Chip = tester.widget<FilterChip>(mondayChips.first);
    final week2Chip = tester.widget<FilterChip>(mondayChips.last);
    expect(week1Chip.selected, isTrue);
    expect(week2Chip.selected, isFalse);
  });
}
