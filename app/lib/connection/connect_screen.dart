import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import 'connection_info.dart';
import 'connection_store.dart';
import 'qr_scan_page.dart';

/// First-run (and re-pairing) screen: connects this device to the backend running on the
/// admin's Windows PC. Mobile builds get a QR-scan shortcut; every platform can fall back to
/// typing the host/port/token shown by the tray app's "Show connection QR" window.
class ConnectScreen extends StatefulWidget {
  final void Function(ConnectionInfo) onConnected;

  const ConnectScreen({super.key, required this.onConnected});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  final TextEditingController _tokenController = TextEditingController();
  bool _connecting = false;
  String? _error;

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    // The backend almost always runs on the same Windows PC as the Windows build of this
    // app, so default to localhost there as a convenience — other platforms leave it blank
    // since they're on a different device by definition.
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    _hostController = TextEditingController(text: isWindows ? 'localhost' : '');
    _portController = TextEditingController(text: '8765');
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _connectWith(ConnectionInfo info) async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    final reachable = await ApiClient(info).checkHealth();
    if (!mounted) return;
    if (!reachable) {
      setState(() {
        _connecting = false;
        _error = 'Could not reach ${info.baseUrl}. Check the address and that the backend is running.';
      });
      return;
    }
    await ConnectionStore.save(info);
    widget.onConnected(info);
  }

  Future<void> _connectManually() async {
    final port = int.tryParse(_portController.text.trim());
    if (_hostController.text.trim().isEmpty || port == null) {
      setState(() => _error = 'Enter a valid host and port.');
      return;
    }
    await _connectWith(
      ConnectionInfo(
        host: _hostController.text.trim(),
        port: port,
        token: _tokenController.text.trim().isEmpty ? null : _tokenController.text.trim(),
      ),
    );
  }

  Future<void> _scanQr() async {
    final info = await Navigator.of(
      context,
    ).push<ConnectionInfo>(MaterialPageRoute(builder: (_) => const QrScanPage()));
    if (info != null) {
      await _connectWith(info);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Connect to Medical Staff Review', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  "Get the connection details from the tray app's \"Show connection QR\" menu "
                  'on the Windows PC running the backend.',
                ),
                const SizedBox(height: 24),
                if (_isMobile) ...[
                  FilledButton.icon(
                    onPressed: _connecting ? null : _scanQr,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR code'),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('or enter manually')), Expanded(child: Divider())],
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(labelText: 'Host / IP address'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _portController,
                  decoration: const InputDecoration(labelText: 'Port'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tokenController,
                  decoration: const InputDecoration(labelText: 'Pairing token'),
                  obscureText: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _connecting ? null : _connectManually,
                  child: _connecting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Connect'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
