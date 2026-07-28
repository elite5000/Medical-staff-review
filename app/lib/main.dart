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
  const MedicalStaffReviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical Staff Review',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const _RootPage(),
    );
  }
}

/// Decides between the pairing screen and the main app shell: tries the connection info
/// persisted from a previous pairing first, falling back to [ConnectScreen] if there is
/// none, or if the previously paired backend can no longer be reached.
class _RootPage extends StatefulWidget {
  const _RootPage();

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
      return ConnectScreen(onConnected: _onConnected);
    }
    return AppShell(api: api, onDisconnect: _disconnect);
  }
}
