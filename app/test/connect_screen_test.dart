import 'dart:async';

import 'package:app/api/api_client.dart';
import 'package:app/connection/connect_screen.dart';
import 'package:app/connection/connection_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers ConnectScreen's search → found / not-found → retry flow with an injected connect
/// function; the real UDP handshake is covered in discovery_test.dart.
void main() {
  testWidgets('shows a searching state while discovery is in flight', (
    tester,
  ) async {
    final pending = Completer<ApiClient?>();
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectScreen(onConnected: (_) {}, connect: () => pending.future),
      ),
    );
    await tester.pump();

    expect(
      find.text('Looking for the backend on this network…'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Retry'), findsNothing);

    pending.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('shows an error with Retry when no backend answers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectScreen(onConnected: (_) {}, connect: () async => null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't find the backend"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });

  testWidgets('Retry searches again and connects once the backend answers', (
    tester,
  ) async {
    final api = ApiClient(ConnectionInfo(host: 'test'));
    final results = <ApiClient?>[null, api];
    ApiClient? connected;

    await tester.pumpWidget(
      MaterialApp(
        home: ConnectScreen(
          onConnected: (a) => connected = a,
          connect: () async => results.removeAt(0),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(connected, isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    // Not pumpAndSettle: on success the spinner stays up until the parent swaps this
    // screen out, so it never settles here.
    await tester.pump();
    await tester.pump();

    expect(connected, same(api));
  });
}
