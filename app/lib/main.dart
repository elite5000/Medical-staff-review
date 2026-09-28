import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'app_shell.dart';
import 'connection/connect_screen.dart';
import 'connection/connection_store.dart';
import 'connection/connection_verifier.dart';

void main() {
  runApp(const MedicalStaffReviewApp());
}

class MedicalStaffReviewApp extends StatelessWidget {
  /// How [ConnectScreen] finds and connects to the backend — overridable for widget tests.
  final Future<ApiClient?> Function() connect;

  const MedicalStaffReviewApp({super.key, this.connect = discoverAndConnect});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical Staff Review',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: _RootPage(connect: connect),
    );
  }
}

/// Decides between the connect screen and the main app shell: tries the connection info
/// persisted from the last successful connection first, falling back to [ConnectScreen]
/// (which rediscovers the backend on the LAN) if there is none, or if it can no longer be
/// reached — e.g. the admin PC's IP address changed.
class _RootPage extends StatefulWidget {
  final Future<ApiClient?> Function() connect;

  const _RootPage({required this.connect});

  @override
  State<_RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<_RootPage> {
  ApiClient? _api;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tryStoredConnection();
  }

  Future<void> _tryStoredConnection() async {
    final stored = await ConnectionStore.load();
    if (stored == null) {
      setState(() => _loading = false);
      return;
    }
    final api = await connectAndVerify(stored);
    if (!mounted) return;
    setState(() {
      _api = api;
      _loading = false;
    });
  }

  void _onConnected(ApiClient api) {
    setState(() => _api = api);
  }

  Future<void> _disconnect() async {
    await ConnectionStore.clear();
    if (mounted) setState(() => _api = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final api = _api;
    if (api == null) {
      return ConnectScreen(onConnected: _onConnected, connect: widget.connect);
    }
    return AppShell(api: api, onDisconnect: _disconnect);
  }
}
