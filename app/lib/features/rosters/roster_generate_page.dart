import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/error_banner.dart';
import 'roster_view_page.dart';

/// Ported from frontend/src/pages/rosters/RosterGeneratePage.svelte.
class RosterGeneratePage extends StatefulWidget {
  final ApiClient api;

  const RosterGeneratePage({super.key, required this.api});

  @override
  State<RosterGeneratePage> createState() => _RosterGeneratePageState();
}

class _RosterGeneratePageState extends State<RosterGeneratePage> {
  final _numDaysController = TextEditingController(text: '14');
  DateTime? _startDate;
  String? _error;
  bool _generating = false;

  @override
  void dispose() {
    _numDaysController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_startDate == null) {
      setState(() => _error = 'A start date is required');
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final roster = await widget.api.generateRoster(
        startDate: _startDate!,
        numDays: int.tryParse(_numDaysController.text.trim()) ?? 14,
      );
      if (!mounted) return;
      // Replaces this page with the roster view, then reports back to RostersPage (via the
      // original push's Future) that a new roster was generated so its list refreshes.
      Navigator.of(context).pop(true);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RosterViewPage(api: widget.api, rosterId: roster.id),
        ),
      );
    } on ApiException catch (e) {
      setState(() {
        _generating = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Roster')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ErrorBanner(message: _error),
          OutlinedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _startDate = picked);
            },
            child: Text(
              _startDate == null ? 'Start date' : dateToJson(_startDate!),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _numDaysController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Number of days'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _generating ? null : _generate,
            child: _generating
                ? const Text('Generating…')
                : const Text('Generate'),
          ),
        ],
      ),
    );
  }
}
