import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/confirm_dialog.dart';
import 'staff_form_page.dart';

/// Ported from frontend/src/pages/staff/StaffListPage.svelte.
class StaffPage extends StatelessWidget {
  final ApiClient api;

  const StaffPage({super.key, required this.api});

  Future<void> _openForm(BuildContext context, VoidCallback reload, {Staff? existing}) async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => StaffFormPage(api: api, existing: existing)));
    if (saved == true) reload();
  }

  Future<void> _delete(BuildContext context, Staff person, VoidCallback reload) async {
    if (!await confirmDialog(context, 'Delete staff member "${person.name}"?')) return;
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
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openForm(context, reload),
          tooltip: 'New Staff Member',
          child: const Icon(Icons.add),
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
