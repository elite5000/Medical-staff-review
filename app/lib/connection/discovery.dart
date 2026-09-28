import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'connection_info.dart';

/// Must match DISCOVERY_REQUEST / SERVICE_NAME in backend/app/discovery.py.
const _discoveryRequest = 'MSR-DISCOVER-1';
const _serviceName = 'medical-staff-review';

/// Finds the backend on the LAN with no user input: broadcasts a discovery request over UDP
/// to [port] and returns the first valid reply as a [ConnectionInfo] — host taken from the
/// reply's source address, token and certificate fingerprint from its payload. Returns null
/// if nothing answers within [timeout].
///
/// [targets] overrides where the request is sent (tests use loopback only); by default it
/// goes to loopback (backend on this PC), the limited broadcast address, and each local
/// interface's /24 directed broadcast — the latter because Windows with several adapters
/// only sends 255.255.255.255 out of one of them.
Future<ConnectionInfo?> discoverBackend({
  int port = backendPort,
  Duration timeout = const Duration(seconds: 3),
  List<InternetAddress>? targets,
}) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  socket.broadcastEnabled = true;
  final result = Completer<ConnectionInfo?>();

  final subscription = socket.listen((event) {
    if (event != RawSocketEvent.read) return;
    final datagram = socket.receive();
    if (datagram == null || result.isCompleted) return;
    final info = parseDiscoveryReply(datagram.data, datagram.address.address);
    if (info != null) result.complete(info);
  });

  final request = utf8.encode(_discoveryRequest);
  for (final target in targets ?? await _defaultTargets()) {
    try {
      socket.send(request, target, port);
    } on SocketException {
      // Unreachable broadcast address on some adapter — the others may still work.
    }
  }

  final info = await result.future.timeout(timeout, onTimeout: () => null);
  await subscription.cancel();
  socket.close();
  return info;
}

/// Parses a backend's UDP reply, or returns null if it isn't one (so stray traffic on the
/// port is ignored rather than treated as a backend).
ConnectionInfo? parseDiscoveryReply(List<int> data, String host) {
  try {
    final json = jsonDecode(utf8.decode(data));
    if (json is! Map<String, dynamic> || json['service'] != _serviceName) {
      return null;
    }
    final token = json['token'];
    final fingerprint = json['cert_fingerprint'];
    if (token is! String? || fingerprint is! String?) return null;
    return ConnectionInfo(
      host: host,
      token: token,
      certFingerprint: fingerprint,
    );
  } on FormatException {
    return null;
  }
}

Future<List<InternetAddress>> _defaultTargets() async {
  final targets = <InternetAddress>[
    InternetAddress.loopbackIPv4,
    InternetAddress('255.255.255.255'),
  ];
  // Android emulators reach the host PC only through this alias; broadcasts don't cross.
  if (Platform.isAndroid) targets.add(InternetAddress('10.0.2.2'));
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final octets = address.rawAddress;
        targets.add(
          InternetAddress.fromRawAddress(
            Uint8List.fromList([octets[0], octets[1], octets[2], 255]),
          ),
        );
      }
    }
  } on SocketException {
    // Interface listing unavailable — loopback + limited broadcast still apply.
  }
  return targets;
}
