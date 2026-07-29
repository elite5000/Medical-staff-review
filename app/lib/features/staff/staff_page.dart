import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/bulk_add_dialog.dart';
import '../../widgets/confirm_dialog.dart';
import 'staff_form_page.dart';

/// Ported from frontend/src/pages/staff/StaffListPage.svelte.
class StaffPage extends StatelessWidget {
  final ApiClient api;

  const StaffPage({super.key, required this.api});

  Future<void> _openForm(
    BuildContext context,
    VoidCallback reload, {
    Staff? existing,
  }) async {
    // Always reload on return, regardless of how the form closed (back button, hardware
    // back, swipe) — StaffFormPage intentionally stays open after a save (to allow adding
    // unavailability), so there's no reliable "did anything change" pop result to key off.
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StaffFormPage(api: api, existing: existing),
      ),
    );
    reload();
  }

  /// Bulk-add is names only: everyone arrives active with no roles or preferred days, which
  /// are then set per person via the single-edit form.
  Future<void> _showBulkForm(BuildContext context, VoidCallback reload) async {
    final created = await showBulkAddDialog(
      context: context,
      title: 'Bulk Add Staff',
      entityLabel: 'staff member',
      entityLabelPlural: 'staff members',
      submit: (names, _) => api.bulkCreateStaff(names),
    );
    if (created) reload();
  }

  Future<void> _delete(
    BuildContext context,
    Staff person,
    VoidCallback reload,
  ) async {
    if (!await confirmDialog(
      context,
      'Delete staff member "${person.name}"?',
    )) {
      return;
    }
    try {
      await api.deleteStaff(person.id);
      reload();
    } on ApiException catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not delete staff member who appears in a generated roster — deactivate instead',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncLoader<List<Staff>>(
      load: api.listStaff,
      builder: (context, staff, reload) => Scaffold(
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
              tooltip: 'Bulk Add Staff',
              child: const Icon(Icons.playlist_add),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              onPressed: () => _openForm(context, reload),
              tooltip: 'New Staff Member',
              child: const Icon(Icons.add),
            ),
          ],
        ),
        body: staff.isEmpty
            ? const Center(child: Text('No staff yet.'))
            : ListView.separated(
                itemCount: staff.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final person = staff[index];
                  return ListTile(
                    title: Text(person.name),
                    subtitle: Text(
                      '${person.active ? 'Active' : 'Inactive'} · '
                      '${person.roles.map((r) => r.name).join(', ')}',
                    ),
                    onTap: () => _openForm(context, reload, existing: person),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () => _delete(context, person, reload),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
