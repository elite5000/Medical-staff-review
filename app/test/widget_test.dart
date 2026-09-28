import 'package:app/api/api_client.dart';
import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the connect screen when no backend has been found yet', (
    tester,
  ) async {
    await tester.pumpWidget(MedicalStaffReviewApp(connect: () async => null));
    await tester.pumpAndSettle();

    expect(find.text('Connect to Medical Staff Review'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    // Nothing to type — discovery supplies every connection detail.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('searches for the backend as soon as the app opens', (
    tester,
  ) async {
    var calls = 0;
    Future<ApiClient?> connect() async {
      calls++;
      return null;
    }

    await tester.pumpWidget(MedicalStaffReviewApp(connect: connect));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });
}
