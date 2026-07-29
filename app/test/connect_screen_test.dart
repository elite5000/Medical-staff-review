import 'package:app/connection/connect_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers ConnectScreen beyond widget_test.dart's two smoke tests (empty-host validation,
/// initial screen). connectAndVerify (connection_verifier.dart) drives a genuine http.Client
/// rather than an injectable one, so a real successful connection can't be exercised here
/// without either a real reachable server — blocked by TestWidgetsFlutterBinding, which
/// forces every HttpClient response to a non-2xx specifically to stop tests from making
/// network calls by accident — or refactoring ConnectScreen for dependency injection, which
/// is out of scope for a coverage pass. The "unreachable backend" path is still testable: it
/// relies on exactly that same forced non-2xx response, so it needs no server at all.
///
/// Deliberately NOT covered here: QR-scan pairing beyond the button's platform-conditional
/// visibility (QrScanPage wraps the mobile_scanner camera plugin — faking its platform
/// channel to test an actual scan would be fragile and low-value) and the
/// certificate-mismatch path (would need a real HTTPS server with a self-signed cert per
/// test, disproportionate effort here).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('rejects a non-numeric port', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ConnectScreen(onConnected: (_) {})),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Host / IP address'),
      'localhost',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Port'),
      'not-a-port',
    );

    final connectButton = find.widgetWithText(FilledButton, 'Connect');
    await tester.ensureVisible(connectButton);
    await tester.tap(connectButton);
    await tester.pump();

    expect(find.text('Enter a valid host and port.'), findsOneWidget);
  });

  testWidgets(
    'rejects a pairing token without a valid certificate fingerprint',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ConnectScreen(onConnected: (_) {})),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Host / IP address'),
        'localhost',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Port'),
        '8765',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Pairing token'),
        'some-token',
      );
      // Left blank/invalid — not the 64-character hex fingerprint the tray app shows.

      final connectButton = find.widgetWithText(FilledButton, 'Connect');
      await tester.ensureVisible(connectButton);
      await tester.tap(connectButton);
      await tester.pump();

      expect(
        find.text(
          'Enter the 64-character certificate fingerprint from the tray app.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows an error when the backend cannot be reached', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ConnectScreen(onConnected: (_) {})),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Host / IP address'),
      'unreachable-host',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Port'),
      '8765',
    );

    final connectButton = find.widgetWithText(FilledButton, 'Connect');
    await tester.ensureVisible(connectButton);
    await tester.tap(connectButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not reach http://unreachable-host:8765'),
      findsOneWidget,
    );
  });

  testWidgets('shows the Scan QR code shortcut only on Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      MaterialApp(home: ConnectScreen(onConnected: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Scan QR code'), findsOneWidget);

    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(
      MaterialApp(home: ConnectScreen(onConnected: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Scan QR code'), findsNothing);

    // Flutter's end-of-test invariant check runs before the outer tearDown, so this override
    // must be cleared here, not just there.
    debugDefaultTargetPlatformOverride = null;
  });
}
