import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/io_client.dart';

import '../api/api_client.dart';
import 'connection_info.dart';
import 'connection_store.dart';

HttpClient _pinnedHttpClient(String expectedFingerprint) {
  return HttpClient()
    ..badCertificateCallback = (cert, host, port) {
      final actual = sha256.convert(cert.der).toString();
      return actual == expectedFingerprint;
    };
}

/// Attempts a connection and, on success, persists it via [ConnectionStore] and returns an
/// [ApiClient] already wired to the right underlying HTTP client — the caller should keep
/// using this same instance for the rest of the session rather than constructing a fresh
/// one.
///
/// For a dev backend (`info.token == null`) this is just [ApiClient.verifyConnection] over
/// plain HTTP. For a packaged backend, it connects over HTTPS and pins the server's
/// certificate: if [info] already has a `certFingerprint` (from a QR scan, or a previous
/// pairing), the presented certificate must match exactly or the connection is rejected —
/// otherwise (manual entry, first time) it trusts whatever certificate is presented on this
/// first connection, so every connection after this one is strictly pinned too.
Future<ApiClient?> connectAndVerify(ConnectionInfo info) async {
  if (info.token == null) {
    final api = ApiClient(info);
    if (!await api.verifyConnection()) return null;
    await ConnectionStore.save(info);
    return api;
  }

  // For packaged builds (token-enabled), manual pairing must include the certificate
  // fingerprint out of band; otherwise the very first TLS connection would be TOFU and
  // could leak the bearer token to an on-path attacker.
  if (info.certFingerprint == null || info.certFingerprint!.isEmpty) {
    return null;
  }

  final probeIoHttpClient = HttpClient()
    ..badCertificateCallback = (cert, host, port) {
      final actual = sha256.convert(cert.der).toString();
      return actual == info.certFingerprint;
    };

  final probeClient = IOClient(probeIoHttpClient);
  try {
    final probeApi = ApiClient(info, httpClient: probeClient);
    if (!await probeApi.verifyConnection()) return null;
  } finally {
    probeClient.close();
  }

  final resolved = ConnectionInfo(
    host: info.host,
    port: info.port,
    token: info.token,
    certFingerprint: info.certFingerprint,
  );
  await ConnectionStore.save(resolved);
  return ApiClient(
    resolved,
    httpClient: IOClient(_pinnedHttpClient(info.certFingerprint!)),
  );
}
