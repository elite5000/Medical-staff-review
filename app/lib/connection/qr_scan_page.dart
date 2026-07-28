import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'connection_info.dart';

/// Full-screen camera scanner for the tray app's connection QR code (payload is JSON:
/// {"host": ..., "port": ..., "token": ...} — see backend/app/desktop/tray.py's
/// _connection_payload). Pops with the parsed [ConnectionInfo] on first successful scan.
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final info = ConnectionInfo.fromJson(json);
      _handled = true;
      Navigator.of(context).pop(info);
    } catch (_) {
      // Not our QR payload (e.g. an unrelated code) — keep scanning.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan connection QR code')),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}
