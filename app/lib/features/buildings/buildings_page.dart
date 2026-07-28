import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/confirm_dialog.dart';

String _formatMinutes(int minutes) {
  final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

/// Ported from frontend/src/pages/buildings/{BuildingsListPage,BuildingFormPage}.svelte.
class BuildingsPage extends StatelessWidget {
  final ApiClient api;

  const BuildingsPage({super.key, required this.api});

  Future<void> _showForm(
    BuildContext context,
    VoidCallback reload, {
    Building? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    // 08:00-16:00 divides evenly into the default 240-minute shift length (see
    // BuildingFormPage.svelte's comment on the same default).
    TimeOfDay opening = existing != null
        ? TimeOfDay(
            hour: existing.openingMinutes ~/ 60,
            minute: existing.openingMinutes % 60,
          )
        : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay closing = existing != null
        ? TimeOfDay(
            hour: existing.closingMinutes ~/ 60,
            minute: existing.closingMinutes % 60,
          )
        : const TimeOfDay(hour: 16, minute: 0);
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(existing == null ? 'New Building' : 'Edit Building'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Opening time'),
                trailing: Text(opening.format(dialogContext)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: dialogContext,
                    initialTime: opening,
                  );
                  if (picked != null) setState(() => opening = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Closing time'),
                trailing: Text(closing.format(dialogContext)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: dialogContext,
                    initialTime: closing,
                  );
                  if (picked != null) setState(() => closing = picked);
                },
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setState(() => error = 'Name is required');
                  return;
                }
                final openingMinutes = opening.hour * 60 + opening.minute;
                final closingMinutes = closing.hour * 60 + closing.minute;
                try {
                  if (existing == null) {
                    await api.createBuilding(
                      name: name,
                      openingMinutes: openingMinutes,
                      closingMinutes: closingMinutes,
                    );
                  } else {
                    await api.updateBuilding(
                      existing.id,
                      name: name,
                      openingMinutes: openingMinutes,
                      closingMinutes: closingMinutes,
                    );
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                } on ApiException catch (e) {
                  setState(() => error = e.message);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) reload();
  }

  Future<void> _delete(
    BuildContext context,
    Building building,
    VoidCallback reload,
  ) async {
    if (!await confirmDialog(context, 'Delete building "${building.name}"?')) {
      return;
    }
    try {
      await api.deleteBuilding(building.id);
      reload();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete building: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncLoader<List<Building>>(
      load: api.listBuildings,
      builder: (context, buildings, reload) => Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showForm(context, reload),
          tooltip: 'New Building',
          child: const Icon(Icons.add),
        ),
        body: buildings.isEmpty
            ? const Center(child: Text('No buildings yet.'))
            : ListView.separated(
                itemCount: buildings.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final building = buildings[index];
                  return ListTile(
                    title: Text(building.name),
                    subtitle: Text(
                      '${_formatMinutes(building.openingMinutes)} - ${_formatMinutes(building.closingMinutes)}',
                    ),
                    onTap: () => _showForm(context, reload, existing: building),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () => _delete(context, building, reload),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
