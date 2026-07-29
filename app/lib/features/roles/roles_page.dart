import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/bulk_add_dialog.dart';
import '../../widgets/confirm_dialog.dart';

/// Ported from frontend/src/pages/roles/{RolesListPage,RoleFormPage}.svelte.
class RolesPage extends StatelessWidget {
  final ApiClient api;

  const RolesPage({super.key, required this.api});

  Future<void> _showForm(
    BuildContext context,
    VoidCallback reload, {
    Role? existing,
  }) async {
    final controller = TextEditingController(text: existing?.name ?? '');
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(existing == null ? 'New Role' : 'Edit Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
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
                final name = controller.text.trim();
                if (name.isEmpty) {
                  setState(() => error = 'Name is required');
                  return;
                }
                try {
                  if (existing == null) {
                    await api.createRole(name);
                  } else {
                    await api.updateRole(existing.id, name);
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
    controller.dispose();
    if (saved == true) reload();
  }

  Future<void> _showBulkForm(BuildContext context, VoidCallback reload) async {
    final created = await showBulkAddDialog(
      context: context,
      title: 'Bulk Add Roles',
      entityLabel: 'role',
      entityLabelPlural: 'roles',
      skipsExistingNames: true,
      submit: (names, _) => api.bulkCreateRoles(names),
    );
    if (created) reload();
  }

  Future<void> _delete(
    BuildContext context,
    Role role,
    VoidCallback reload,
  ) async {
    if (!await confirmDialog(context, 'Delete role "${role.name}"?')) return;
    try {
      await api.deleteRole(role.id);
      reload();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete role: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncLoader<List<Role>>(
      load: api.listRoles,
      builder: (context, roles, reload) => Scaffold(
        // These list pages have no AppBar of their own (AppShell owns the only one, and
        // only at phone widths), so bulk-add sits as a small FAB above the single-add one
        // rather than as an app bar action.
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.small(
              // Two FABs in one Scaffold otherwise share FloatingActionButton's default
              // hero tag and trip Flutter's duplicate-hero assertion on route transitions.
              heroTag: null,
              onPressed: () => _showBulkForm(context, reload),
              tooltip: 'Bulk Add Roles',
              child: const Icon(Icons.playlist_add),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              onPressed: () => _showForm(context, reload),
              tooltip: 'New Role',
              child: const Icon(Icons.add),
            ),
          ],
        ),
        body: roles.isEmpty
            ? const Center(child: Text('No roles yet.'))
            : ListView.separated(
                itemCount: roles.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final role = roles[index];
                  return ListTile(
                    title: Text(role.name),
                    onTap: () => _showForm(context, reload, existing: role),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () => _delete(context, role, reload),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
