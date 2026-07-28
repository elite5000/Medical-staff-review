import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/error_banner.dart';

/// Ported from frontend/src/pages/settings/SettingsPage.svelte.
class SettingsPage extends StatefulWidget {
  final ApiClient api;

  const SettingsPage({super.key, required this.api});

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
    setState(() {
      _saving = true;
      _error = null;
      _saved = false;
    });
    try {
      await widget.api.updateSettings(
        shiftLengthMinutes: int.tryParse(_shiftLengthController.text.trim()),
        travelTimeMinutes: int.tryParse(_travelTimeController.text.trim()),
        maxDailyMinutes: int.tryParse(_maxDailyController.text.trim()),
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
              const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Saved.')),
            TextField(
              controller: _shiftLengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Shift length (minutes)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _travelTimeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Travel time between buildings (minutes)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _maxDailyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Max daily hours (minutes)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
