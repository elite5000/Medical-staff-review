import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'connection_info.dart';

/// Persists the paired backend's connection details across app restarts, so the admin only
/// scans the tray app's QR code (or types the address) once per device.
class ConnectionStore {
  static const _prefsKey = 'connection_info';

  static Future<ConnectionInfo?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;
    return ConnectionInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> save(ConnectionInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(info.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
