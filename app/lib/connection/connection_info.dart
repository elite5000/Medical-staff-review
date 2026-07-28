class ConnectionInfo {
  final String host;
  final int port;

  /// Null/empty when talking to a dev backend that has no pairing token configured
  /// (see backend/app/config.py's _default_pairing_token — only packaged builds set one).
  final String? token;

  ConnectionInfo({required this.host, required this.port, this.token});

  String get baseUrl => 'http://$host:$port';

  Map<String, dynamic> toJson() => {'host': host, 'port': port, 'token': token};

  factory ConnectionInfo.fromJson(Map<String, dynamic> json) => ConnectionInfo(
    host: json['host'] as String,
    port: json['port'] as int,
    token: json['token'] as String?,
  );
}
