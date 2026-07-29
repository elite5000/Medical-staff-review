import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/error_banner.dart';

/// Grants one role to many staff members in a single action, as a full page (pushed from
/// RolesPage) rather than a dialog since it needs a role picker plus a searchable staff
/// checklist loaded from two endpoints.
///
/// Applying is *additive* server-side (see POST /roles/{id}/apply-to-staff) — unlike the
/// per-staff edit form, which replaces a staff member's roles wholesale — so a bulk apply
/// never strips roles somebody already holds.
class BulkApplyRolePage extends StatefulWidget {
  final ApiClient api;

  const BulkApplyRolePage({super.key, required this.api});

  @override
  State<BulkApplyRolePage> createState() => _BulkApplyRolePageState();
}

class _BulkApplyRolePageState extends State<BulkApplyRolePage> {
  final _searchController = TextEditingController();

  /// The single source of truth for checkbox state. Deliberately survives an Apply (only
  /// the explicit "Clear selection" control empties it) so the same set of staff can be
  /// given several roles in a row without re-ticking every box.
  final Set<int> _selectedStaffIds = {};
  int? _roleId;
  String? _error;
  bool _applying = false;

  /// Set by AsyncLoader's builder on every run so _apply() can refetch staff afterwards —
  /// without it the role chips would still show each staff member's pre-apply roles.
  VoidCallback? _reload;

  @override
  void initState() {
    super.initState();
    // Filtering is derived from the controller's text at build time, so every keystroke
    // needs a rebuild.
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _apply(List<Role> roles) async {
    final roleId = _roleId;
    if (roleId == null || _selectedStaffIds.isEmpty) return;
    setState(() {
      _applying = true;
      _error = null;
    });
    try {
      final updated = await widget.api.applyRoleToStaff(
        roleId,
        _selectedStaffIds.toList(),
      );
      if (!mounted) return;
      setState(() => _applying = false);
      final roleName = roles
          .where((r) => r.id == roleId)
          .map((r) => r.name)
          .firstOrNull;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Applied "${roleName ?? 'role'}" to ${updated.length} '
            '${updated.length == 1 ? 'staff member' : 'staff members'}.',
          ),
        ),
      );
      // Refetch so the role chips below reflect the change. Note this intentionally leaves
      // _selectedStaffIds alone.
      _reload?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _applying = false;
        _error = e.message;
      });
    }
  }

  Widget _staffTile(Staff person) {
    return CheckboxListTile(
      value: _selectedStaffIds.contains(person.id),
      onChanged: (checked) => setState(() {
        if (checked == true) {
          _selectedStaffIds.add(person.id);
        } else {
          _selectedStaffIds.remove(person.id);
        }
      }),
      title: Text(person.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(person.active ? 'Active' : 'Inactive'),
          if (person.roles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final role in person.roles)
                    Chip(
                      label: Text(role.name),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply Role to Staff')),
      body: AsyncLoader<(List<Role>, List<Staff>)>(
        load: () async {
          final roles = await widget.api.listRoles();
          final staff = await widget.api.listStaff();
          // Falls back to the first role both on first load and if the picked one has since
          // been deleted elsewhere — DropdownButtonFormField asserts when its value isn't
          // among its items.
          if (!roles.any((r) => r.id == _roleId)) {
            _roleId = roles.firstOrNull?.id;
          }
          return (roles, staff);
        },
        builder: (context, data, reload) {
          _reload = reload;
          final (roles, staff) = data;
          final query = _searchController.text.trim().toLowerCase();
          final visible = query.isEmpty
              ? staff
              : staff
                    .where((p) => p.name.toLowerCase().contains(query))
                    .toList();

          return Column(
            children: [
              ErrorBanner(message: _error),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _roleId,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: roles
                          .map(
                            (r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(r.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _roleId = value),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search staff',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          staff.isEmpty
                              ? 'No staff yet.'
                              : 'No staff match "${_searchController.text.trim()}".',
                        ),
                      )
                    : ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            _staffTile(visible[index]),
                      ),
              ),
              const Divider(height: 1),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              _applying ||
                                  _roleId == null ||
                                  _selectedStaffIds.isEmpty
                              ? null
                              : () => _apply(roles),
                          child: _applying
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Apply to ${_selectedStaffIds.length} selected',
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _selectedStaffIds.isEmpty
                            ? null
                            : () => setState(_selectedStaffIds.clear),
                        child: const Text('Clear selection'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
