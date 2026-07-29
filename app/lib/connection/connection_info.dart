class ConnectionInfo {
  final String host;
  final int port;

  /// Null/empty when talking to a dev backend that has no pairing token configured
  /// (see backend/app/config.py's _default_pairing_token — only packaged builds set one).
  final String? token;

  /// SHA-256 fingerprint (hex) of the packaged backend's self-signed TLS certificate — null
  /// until either the QR payload supplies one, or the first successful connection captures
  /// it via trust-on-first-use (see connection_verifier.dart). Always null alongside [token]
  /// for a dev backend, which serves plain HTTP.
  final String? certFingerprint;

  ConnectionInfo({
    required this.host,
    required this.port,
    this.token,
    this.certFingerprint,
  });

  // https whenever there's a pairing token (the existing signal for "packaged build") —
  // dev backends have neither a token nor TLS.
  String get baseUrl =>
      token != null ? 'https://$host:$port' : 'http://$host:$port';

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'token': token,
    'cert_fingerprint': certFingerprint,
  };

  factory ConnectionInfo.fromJson(Map<String, dynamic> json) => ConnectionInfo(
    host: json['host'] as String,
    port: json['port'] as int,
    token: json['token'] as String?,
    certFingerprint: json['cert_fingerprint'] as String?,
  );
}
