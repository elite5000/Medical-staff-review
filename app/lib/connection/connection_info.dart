/// The backend's fixed port — must match PORT in backend/app/desktop/tray.py. Dev backends
/// are started on the same port (see the READMEs), so it's never user-entered.
const int backendPort = 8765;

class ConnectionInfo {
  final String host;

  /// Always [backendPort] in the app; only overridden by tests that stand up a local server
  /// on an ephemeral port.
  final int port;

  /// Null/empty when talking to a dev backend that has no pairing token configured
  /// (see backend/app/config.py's _default_pairing_token — only packaged builds set one).
  final String? token;

  /// SHA-256 fingerprint (hex) of the packaged backend's self-signed TLS certificate, handed
  /// out by the discovery handshake (see discovery.dart) and pinned from then on. Always
  /// null alongside [token] for a dev backend, which serves plain HTTP.
  final String? certFingerprint;

  ConnectionInfo({
    required this.host,
    this.port = backendPort,
    this.token,
    this.certFingerprint,
  });

  // https whenever there's a pairing token (the existing signal for "packaged build") —
  // dev backends have neither a token nor TLS.
  String get baseUrl =>
      token != null ? 'https://$host:$port' : 'http://$host:$port';

  Map<String, dynamic> toJson() => {
    'host': host,
    'token': token,
    'cert_fingerprint': certFingerprint,
  };

  // Any 'port' in older saved connections is ignored in favour of the fixed backendPort.
  factory ConnectionInfo.fromJson(Map<String, dynamic> json) => ConnectionInfo(
    host: json['host'] as String,
    token: json['token'] as String?,
    certFingerprint: json['cert_fingerprint'] as String?,
  );
}
