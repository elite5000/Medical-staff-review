import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/io_client.dart';

import '../api/api_client.dart';
import 'connection_info.dart';
import 'connection_store.dart';

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

  String? capturedFingerprint;
  final ioHttpClient = HttpClient()
    ..badCertificateCallback = (cert, host, port) {
      final actual = sha256.convert(cert.der).toString();
      if (info.certFingerprint == null) {
        capturedFingerprint = actual;
        return true;
      }
      return actual == info.certFingerprint;
    };

  final probeApi = ApiClient(info, httpClient: IOClient(ioHttpClient));
  if (!await probeApi.verifyConnection()) return null;

  final resolved = capturedFingerprint == null
      ? info
      : ConnectionInfo(
          host: info.host,
          port: info.port,
          token: info.token,
          certFingerprint: capturedFingerprint,
        );
  await ConnectionStore.save(resolved);
  return ApiClient(resolved, httpClient: IOClient(ioHttpClient));
}
