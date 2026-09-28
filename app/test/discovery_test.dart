import 'dart:convert';
import 'dart:io';

import 'package:app/connection/discovery.dart';
import 'package:test/test.dart';

/// Covers the client side of the LAN discovery handshake (backend side:
/// backend/app/discovery.py), including a real UDP round trip against a fake responder on
/// an ephemeral loopback port.
void main() {
  group('parseDiscoveryReply', () {
    test('reads token and fingerprint, taking host from the sender', () {
      final info = parseDiscoveryReply(
        utf8.encode(
          jsonEncode({
            'service': 'medical-staff-review',
            'token': 'tok',
            'cert_fingerprint': 'ab' * 32,
          }),
        ),
        '192.168.1.20',
      );

      expect(info, isNotNull);
      expect(info!.host, '192.168.1.20');
      expect(info.token, 'tok');
      expect(info.certFingerprint, 'ab' * 32);
      expect(info.baseUrl, 'https://192.168.1.20:8765');
    });

    test('dev backend reply means plain HTTP', () {
      final info = parseDiscoveryReply(
        utf8.encode(
          jsonEncode({
            'service': 'medical-staff-review',
            'token': null,
            'cert_fingerprint': null,
          }),
        ),
        '127.0.0.1',
      );

      expect(info!.baseUrl, 'http://127.0.0.1:8765');
    });

    test('ignores other services and garbage', () {
      expect(
        parseDiscoveryReply(utf8.encode('{"service": "other"}'), 'h'),
        isNull,
      );
      expect(parseDiscoveryReply(utf8.encode('not json'), 'h'), isNull);
      expect(parseDiscoveryReply(utf8.encode('[1, 2]'), 'h'), isNull);
      expect(
        parseDiscoveryReply(
          utf8.encode('{"service": "medical-staff-review", "token": 5}'),
          'h',
        ),
        isNull,
      );
    });
  });

  group('discoverBackend', () {
    late RawDatagramSocket responder;

    setUp(() async {
      responder = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      responder.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = responder.receive();
        if (datagram == null) return;
        if (utf8.decode(datagram.data) != 'MSR-DISCOVER-1') return;
        responder.send(
          utf8.encode(
            jsonEncode({
              'service': 'medical-staff-review',
              'token': 'tok',
              'cert_fingerprint': 'cd' * 32,
            }),
          ),
          datagram.address,
          datagram.port,
        );
      });
    });

    tearDown(() => responder.close());

    test('finds a responding backend', () async {
      final info = await discoverBackend(
        port: responder.port,
        targets: [InternetAddress.loopbackIPv4],
      );

      expect(info, isNotNull);
      expect(info!.host, '127.0.0.1');
      expect(info.token, 'tok');
      expect(info.certFingerprint, 'cd' * 32);
    });

    test('returns null when nothing answers', () async {
      final silent = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(silent.close);

      final info = await discoverBackend(
        port: silent.port,
        targets: [InternetAddress.loopbackIPv4],
        timeout: const Duration(milliseconds: 300),
      );

      expect(info, isNull);
    });
  });
}
