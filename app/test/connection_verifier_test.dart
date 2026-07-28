import 'dart:convert';
import 'dart:io';

import 'package:app/connection/connection_info.dart';
import 'package:app/connection/connection_verifier.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

/// Proves connectAndVerify's certificate-pinning logic directly against a real TLS server
/// (test/fixtures/test_{cert,key}.pem — a plain self-signed cert, regenerable via
/// `openssl req -x509 -newkey rsa:2048 -keyout test_key.pem -out test_cert.pem -days 3650
/// -nodes -subj "/CN=localhost"`), rather than assuming the callback logic is right — an
/// inverted comparison here would silently accept any certificate, defeating the entire
/// point of pinning.
///
/// Deliberately `package:test`, not `flutter_test`: TestWidgetsFlutterBinding installs an
/// HttpOverrides that fakes every HTTP response with a 400, precisely to stop widget tests
/// from hitting real networks — which would defeat this test's entire point of proving
/// behavior against a real TLS handshake.
void main() {
  late String expectedFingerprint;
  late HttpServer server;

  setUpAll(() {
    final certPem = File('test/fixtures/test_cert.pem').readAsStringSync();
    final der = base64.decode(
      certPem
          .replaceAll('-----BEGIN CERTIFICATE-----', '')
          .replaceAll('-----END CERTIFICATE-----', '')
          .replaceAll(RegExp(r'\s'), ''),
    );
    expectedFingerprint = sha256.convert(der).toString();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final context = SecurityContext()
      ..useCertificateChain('test/fixtures/test_cert.pem')
      ..usePrivateKey('test/fixtures/test_key.pem');
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
    await server.close(force: true);
  });

  test(
    'accepts a connection whose certificate matches the pinned fingerprint',
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
    'trusts and pins whatever certificate is presented on first connect',
    () async {
      final api = await connectAndVerify(
        ConnectionInfo(
          host: '127.0.0.1',
          port: server.port,
          token: 'test-token',
        ),
      );
      expect(api, isNotNull);
      expect(api!.connection.certFingerprint, expectedFingerprint);
    },
  );
}
