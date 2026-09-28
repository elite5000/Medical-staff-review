import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/io_client.dart';

import '../api/api_client.dart';
import 'connection_info.dart';
import 'connection_store.dart';

HttpClient _pinnedHttpClient(String expectedFingerprint) {
  return newBackendHttpClient()
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
/// certificate to `info.certFingerprint` (from the discovery handshake, or the stored
/// connection) — a mismatched certificate rejects the connection.
Future<ApiClient?> connectAndVerify(ConnectionInfo info) async {
  if (info.token == null) {
    final api = ApiClient(info);
    if (!await api.verifyConnection()) return null;
    await ConnectionStore.save(info);
    return api;
  }

  // A packaged (token-enabled) backend always hands out its fingerprint during discovery;
  // without one there's nothing to pin, so don't send the bearer token at all.
  if (info.certFingerprint == null || info.certFingerprint!.isEmpty) {
    return null;
  }

  final probeClient = IOClient(_pinnedHttpClient(info.certFingerprint!));
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
