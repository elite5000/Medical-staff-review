import 'dart:convert';
import 'dart:io';

import 'package:app/connection/connection_info.dart';
import 'package:app/connection/connection_verifier.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

/// Proves connectAndVerify's certificate-pinning logic directly against a real TLS server
/// (using a caller-supplied self-signed cert/key via environment variables), rather than
/// assuming the callback logic is right — an inverted comparison here would silently accept
/// any certificate, defeating the entire point of pinning.
///
/// Deliberately `package:test`, not `flutter_test`: TestWidgetsFlutterBinding installs an
/// HttpOverrides that fakes every HTTP response with a 400, precisely to stop widget tests
/// from hitting real networks — which would defeat this test's entire point of proving
/// behavior against a real TLS handshake.
void main() {
  final certPathFromEnv = Platform.environment['MSR_TEST_TLS_CERT'];
  final keyPathFromEnv = Platform.environment['MSR_TEST_TLS_KEY'];
  final missingTlsFixtures =
      certPathFromEnv == null ||
      certPathFromEnv.isEmpty ||
      keyPathFromEnv == null ||
      keyPathFromEnv.isEmpty;
  final certPath = certPathFromEnv ?? '';
  final keyPath = keyPathFromEnv ?? '';

  late String expectedFingerprint;
  late HttpServer server;

  setUpAll(() {
    if (missingTlsFixtures) {
      return;
    }
    final certPem = File(certPath).readAsStringSync();
    final der = base64.decode(
      certPem
          .replaceAll('-----BEGIN CERTIFICATE-----', '')
          .replaceAll('-----END CERTIFICATE-----', '')
          .replaceAll(RegExp(r'\s'), ''),
    );
    expectedFingerprint = sha256.convert(der).toString();
  });

  setUp(() async {
    if (missingTlsFixtures) {
      return;
    }
    SharedPreferences.setMockInitialValues({});
    final context = SecurityContext()
      ..useCertificateChain(certPath)
      ..usePrivateKey(keyPath);
    server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    server.listen((request) {
      request.response.statusCode = 200;
      request.response.close();
    });
  });

  tearDown(() async {
    if (missingTlsFixtures) {
      return;
    }
    await server.close(force: true);
  });

  test(
    'accepts a connection whose certificate matches the pinned fingerprint',
    skip: missingTlsFixtures
        ? 'Set MSR_TEST_TLS_CERT and MSR_TEST_TLS_KEY to run TLS pinning integration tests.'
        : false,
    () async {
      final api = await connectAndVerify(
        ConnectionInfo(
          host: '127.0.0.1',
          port: server.port,
          token: 'test-token',
          certFingerprint: expectedFingerprint,
        ),
      );
      expect(api, isNotNull);
    },
  );

  test(
    'rejects a connection whose certificate does not match the pinned fingerprint',
    skip: missingTlsFixtures
        ? 'Set MSR_TEST_TLS_CERT and MSR_TEST_TLS_KEY to run TLS pinning integration tests.'
        : false,
    () async {
      final api = await connectAndVerify(
        ConnectionInfo(
          host: '127.0.0.1',
          port: server.port,
          token: 'test-token',
          certFingerprint: 'a' * 64, // well-formed but wrong
        ),
      );
      expect(api, isNull);
    },
  );

  test(
    'rejects token-protected connections without a certificate fingerprint',
    skip: missingTlsFixtures
        ? 'Set MSR_TEST_TLS_CERT and MSR_TEST_TLS_KEY to run TLS pinning integration tests.'
        : false,
    () async {
      final api = await connectAndVerify(
        ConnectionInfo(
          host: '127.0.0.1',
          port: server.port,
          token: 'test-token',
        ),
      );
      expect(api, isNull);
    },
  );
}
