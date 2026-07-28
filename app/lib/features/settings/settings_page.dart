import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_banner.dart';

/// Ported from frontend/src/pages/settings/SettingsPage.svelte, plus a Disconnect action
/// (not present in the Svelte app, which had no pairing concept) — the only way back to the
/// connect screen once paired, needed if the pairing token changes or the admin wants to
/// point this device at a different backend (see main.dart's _RootPage._disconnect).
class SettingsPage extends StatefulWidget {
  final ApiClient api;
  final VoidCallback onDisconnect;

  const SettingsPage({
    super.key,
    required this.api,
    required this.onDisconnect,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _shiftLengthController = TextEditingController();
  final _travelTimeController = TextEditingController();
  final _maxDailyController = TextEditingController();
  String? _error;
  bool _saved = false;
  bool _saving = false;

  void _populate(AppSettings settings) {
    _shiftLengthController.text = settings.shiftLengthMinutes.toString();
    _travelTimeController.text = settings.travelTimeMinutes.toString();
    _maxDailyController.text = settings.maxDailyMinutes.toString();
  }

  @override
  void dispose() {
    _shiftLengthController.dispose();
    _travelTimeController.dispose();
    _maxDailyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // ApiClient.updateSettings omits null fields from the PATCH body entirely (so a partial
    // update only touches the fields you pass) — an unparseable/empty field must be caught
    // here rather than silently sent as null, or the backend keeps its old value while this
    // page claims "Saved." with the invalid text still showing.
    final shiftLengthMinutes = int.tryParse(_shiftLengthController.text.trim());
    final travelTimeMinutes = int.tryParse(_travelTimeController.text.trim());
    final maxDailyMinutes = int.tryParse(_maxDailyController.text.trim());
    if (shiftLengthMinutes == null || shiftLengthMinutes <= 0) {
      setState(
        () => _error = 'Shift length must be a positive number of minutes',
      );
      return;
    }
    if (travelTimeMinutes == null || travelTimeMinutes < 0) {
      setState(
        () =>
            _error = 'Travel time must be zero or a positive number of minutes',
      );
      return;
    }
    if (maxDailyMinutes == null || maxDailyMinutes <= 0) {
      setState(
        () => _error = 'Max daily hours must be a positive number of minutes',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _saved = false;
    });
    try {
      await widget.api.updateSettings(
        shiftLengthMinutes: shiftLengthMinutes,
        travelTimeMinutes: travelTimeMinutes,
        maxDailyMinutes: maxDailyMinutes,
      );
      setState(() {
        _saving = false;
        _saved = true;
      });
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncLoader<AppSettings>(
      load: widget.api.getSettings,
      builder: (context, settings, _) {
        if (_shiftLengthController.text.isEmpty) _populate(settings);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ErrorBanner(message: _error),
            if (_saved)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Saved.'),
              ),
            TextField(
              controller: _shiftLengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Shift length (minutes)',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _travelTimeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Travel time between buildings (minutes)',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _maxDailyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max daily hours (minutes)',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
            const Divider(height: 48),
            OutlinedButton(
              onPressed: () async {
                if (await confirmDialog(
                  context,
                  'Disconnect from this backend? You\'ll need to pair again '
                  '(scan the QR code or enter its address) to reconnect.',
                  confirmLabel: 'Disconnect',
                )) {
                  widget.onDisconnect();
                }
              },
              child: const Text('Disconnect'),
            ),
          ],
        );
      },
    );
  }
}
