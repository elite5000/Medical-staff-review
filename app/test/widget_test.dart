import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the connect screen when no backend has been paired', (
    tester,
  ) async {
    await tester.pumpWidget(const MedicalStaffReviewApp());
    await tester.pumpAndSettle();

    expect(find.text('Connect to Medical Staff Review'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Host / IP address'), findsOneWidget);
  });

  testWidgets('rejects manual connect with an empty host', (tester) async {
    await tester.pumpWidget(const MedicalStaffReviewApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Host / IP address'),
      '',
    );
    // The form sits in a SingleChildScrollView taller than the default test viewport, so the
    // Connect button starts off-screen — scroll it into view before tapping.
    final connectButton = find.widgetWithText(FilledButton, 'Connect');
    await tester.ensureVisible(connectButton);
    await tester.tap(connectButton);
    await tester.pump();

    expect(find.text('Enter a valid host and port.'), findsOneWidget);
  });
}
