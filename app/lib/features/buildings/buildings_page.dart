import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/confirm_dialog.dart';

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
    // BuildingFormPage.svelte's comment on the same default). Tracked as raw minutes, not
    // TimeOfDay, since closing_minutes can be 1440 (midnight) — TimeOfDay's hour only goes
    // to 23, so this only converts to/from TimeOfDay transiently, when the picker is
    // actually opened, rather than holding the state in a form TimeOfDay can't represent.
    int openingMinutes = existing?.openingMinutes ?? 8 * 60;
    int closingMinutes = existing?.closingMinutes ?? 16 * 60;
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
                trailing: Text(formatClockMinutes(openingMinutes)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: dialogContext,
                    initialTime: TimeOfDay(
                      hour: (openingMinutes ~/ 60) % 24,
                      minute: openingMinutes % 60,
                    ),
                  );
                  if (picked != null) {
                    setState(
                      () => openingMinutes = picked.hour * 60 + picked.minute,
                    );
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Closing time'),
                trailing: Text(formatClockMinutes(closingMinutes)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: dialogContext,
                    initialTime: TimeOfDay(
                      hour: (closingMinutes ~/ 60) % 24,
                      minute: closingMinutes % 60,
                    ),
                  );
                  if (picked != null) {
                    // 0 is never a valid closing time (closing must be strictly after
                    // opening, and opening is always >= 0) — picking 00:00 can only mean
                    // "closes at the end of the day", i.e. the backend's 1440, not 0.
                    final pickedMinutes = picked.hour * 60 + picked.minute;
                    setState(
                      () => closingMinutes = pickedMinutes == 0
                          ? 1440
                          : pickedMinutes,
                    );
                  }
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
                      '${formatClockMinutes(building.openingMinutes)} - ${formatClockMinutes(building.closingMinutes)}',
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
