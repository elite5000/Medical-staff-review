import 'package:flutter/material.dart';

import '../api/api_client.dart';
import 'connection_verifier.dart';
import 'discovery.dart';

/// Finds the backend on the LAN and connects in one step (see discovery.dart).
Future<ApiClient?> discoverAndConnect() async {
  final info = await discoverBackend();
  if (info == null) return null;
  return connectAndVerify(info);
}

/// Shown when there's no working stored connection: searches the network for the backend
/// automatically on open, with a Retry button if nothing answers. There's nothing to type —
/// the host, port, pairing token and certificate all come from the discovery handshake.
class ConnectScreen extends StatefulWidget {
  final void Function(ApiClient) onConnected;

  /// Overridable so widget tests don't touch the real network.
  final Future<ApiClient?> Function() connect;

  const ConnectScreen({
    super.key,
    required this.onConnected,
    this.connect = discoverAndConnect,
  });

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _searching = true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    final api = await widget.connect();
    if (!mounted) return;
    if (api == null) {
      setState(() => _searching = false);
      return;
    }
    widget.onConnected(api);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Connect to Medical Staff Review',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_searching) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Looking for the backend on this network…'),
                ] else ...[
                  Text(
                    "Couldn't find the backend. Check that it's running on the admin PC "
                    'and that this device is on the same network.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _search, child: const Text('Retry')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
