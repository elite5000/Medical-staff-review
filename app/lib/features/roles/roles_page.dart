import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/bulk_add_dialog.dart';
import '../../widgets/confirm_dialog.dart';
import 'bulk_apply_role_page.dart';

/// Ported from frontend/src/pages/roles/{RolesListPage,RoleFormPage}.svelte.
class RolesPage extends StatelessWidget {
  final ApiClient api;

  const RolesPage({super.key, required this.api});

  Future<void> _showForm(
    BuildContext context,
    VoidCallback reload, {
    Role? existing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _RoleFormDialog(api: api, existing: existing),
    );
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

  /// No reload on return: the bulk-apply page only edits which staff hold which roles, so
  /// the role list this page shows is unaffected by anything done in there.
  void _openBulkApply(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => BulkApplyRolePage(api: api)),
    );
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
        // A FAB group rather than app bar actions: list pages here are hosted inside
        // AppShell, which owns the app bar (and only renders one at phone widths), so a
        // page-level action has nowhere to live up there. Explicit heroTags because multiple
        // FABs on one Scaffold otherwise collide on the default tag.
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'applyRoleToStaff',
              onPressed: () => _openBulkApply(context),
              tooltip: 'Apply to staff',
              child: const Icon(Icons.group_add),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.small(
              heroTag: 'bulkAddRoles',
              onPressed: () => _showBulkForm(context, reload),
              tooltip: 'Bulk Add Roles',
              child: const Icon(Icons.playlist_add),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'newRole',
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

class _RoleFormDialog extends StatefulWidget {
  final ApiClient api;
  final Role? existing;

  const _RoleFormDialog({required this.api, required this.existing});

  @override
  State<_RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<_RoleFormDialog> {
  // Owned by this State (not created/disposed by the caller) so Flutter only disposes it once
  // this widget is actually removed from the tree — i.e. after the dialog's exit transition
  // finishes, not the moment Navigator.pop() is called. Disposing it eagerly right after
  // showDialog's Future resolves races that still-animating transition and crashes with
  // "A TextEditingController was used after being disposed."
  late final TextEditingController _controller = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    try {
      final existing = widget.existing;
      if (existing == null) {
        await widget.api.createRole(name);
      } else {
        await widget.api.updateRole(existing.id, name);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New Role' : 'Edit Role'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
