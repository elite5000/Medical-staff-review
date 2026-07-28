import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/error_banner.dart';
import 'unavailability_calendar.dart';

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Ported from frontend/src/pages/staff/StaffFormPage.svelte. On first save of a new staff
/// member this switches in place into "edit" mode (rather than popping) — mirroring the
/// Svelte page's redirect to /staff/{id}/edit — since unavailability can only be added once
/// the staff member has an id.
class StaffFormPage extends StatefulWidget {
  final ApiClient api;
  final Staff? existing;

  const StaffFormPage({super.key, required this.api, this.existing});

  @override
  State<StaffFormPage> createState() => _StaffFormPageState();
}

class _StaffFormPageState extends State<StaffFormPage> {
  late final TextEditingController _nameController;
  final _uaReasonController = TextEditingController();
  bool _active = true;
  final Set<int> _selectedRoleIds = {};
  final Set<int> _preferredWeek1 = {};
  final Set<int> _preferredWeek2 = {};
  List<Unavailability> _unavailabilities = [];
  int? _staffId;
  DateTime? _uaStart;
  DateTime? _uaEnd;
  String? _error;
  bool _saving = false;
  // Saving a new staff member switches this page into edit mode in place rather than
  // popping (see the class doc comment), so StaffPage's list only learns about the mutation
  // when this page eventually closes — track whether that's actually happened.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _active = existing?.active ?? true;
    _staffId = existing?.id;
    _selectedRoleIds.addAll(existing?.roles.map((r) => r.id) ?? const []);
    for (final pd in existing?.preferredDays ?? const <PreferredDay>[]) {
      (pd.week == 0 ? _preferredWeek1 : _preferredWeek2).add(pd.dayOfWeek);
    }
    _unavailabilities = List.of(existing?.unavailabilities ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _uaReasonController.dispose();
    super.dispose();
  }

  void _toggle(Set<int> set, int value) {
    setState(() {
      if (set.contains(value)) {
        set.remove(value);
      } else {
        set.add(value);
      }
    });
  }

  List<PreferredDay> _buildPreferredDays() => [
    for (final d in _preferredWeek1) PreferredDay(week: 0, dayOfWeek: d),
    for (final d in _preferredWeek2) PreferredDay(week: 1, dayOfWeek: d),
  ];

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_staffId == null) {
        final created = await widget.api.createStaff(
          name: name,
          active: _active,
          roleIds: _selectedRoleIds.toList(),
          preferredDays: _buildPreferredDays(),
        );
        setState(() {
          _staffId = created.id;
          _saving = false;
          _dirty = true;
        });
      } else {
        await widget.api.updateStaff(
          _staffId!,
          name: name,
          active: _active,
          roleIds: _selectedRoleIds.toList(),
          preferredDays: _buildPreferredDays(),
        );
        setState(() {
          _saving = false;
          _dirty = true;
        });
      }
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  Future<void> _addUnavailability() async {
    final staffId = _staffId;
    if (staffId == null || _uaStart == null || _uaEnd == null) return;
    try {
      final created = await widget.api.addUnavailability(
        staffId,
        startDate: _uaStart!,
        endDate: _uaEnd!,
        reason: _uaReasonController.text.trim().isEmpty
            ? null
            : _uaReasonController.text.trim(),
      );
      setState(() {
        _unavailabilities = [..._unavailabilities, created];
        _uaStart = null;
        _uaEnd = null;
        _uaReasonController.clear();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _removeUnavailability(Unavailability u) async {
    final staffId = _staffId;
    if (staffId == null) return;
    try {
      await widget.api.removeUnavailability(staffId, u.id);
      setState(
        () => _unavailabilities = _unavailabilities
            .where((x) => x.id != u.id)
            .toList(),
      );
    } on ApiException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove unavailability')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // canPop: false + manually popping with _dirty on every pop attempt (AppBar back
    // button, hardware back, swipe gesture) is what makes StaffPage's list reload after a
    // save — see the _dirty field's doc comment for why a plain Navigator.pop(true) in
    // _save() isn't enough.
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_dirty);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _staffId == null ? 'New Staff Member' : 'Edit Staff Member',
          ),
        ),
        body: AsyncLoader<(List<Role>, List<Staff>)>(
          load: () async {
            final roles = await widget.api.listRoles();
            final allStaff = await widget.api.listStaff();
            return (roles, allStaff);
          },
          builder: (context, data, _) {
            final (roles, allStaff) = data;
            // Overlays this staff member's live-edited unavailabilities onto the fetched list,
            // so the calendar reflects add/remove immediately without a full refetch.
            final calendarStaff = allStaff
                .map(
                  (person) => person.id == _staffId
                      ? Staff(
                          id: person.id,
                          name: person.name,
                          active: person.active,
                          roles: person.roles,
                          preferredDays: person.preferredDays,
                          unavailabilities: _unavailabilities,
                        )
                      : person,
                )
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ErrorBanner(message: _error),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v ?? true),
                ),
                const SizedBox(height: 8),
                Text('Roles', style: Theme.of(context).textTheme.titleMedium),
                for (final role in roles)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(role.name),
                    value: _selectedRoleIds.contains(role.id),
                    onChanged: (_) => _toggle(_selectedRoleIds, role.id),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Preferred days — Week 1',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < _dayNames.length; i++)
                      FilterChip(
                        label: Text(_dayNames[i]),
                        selected: _preferredWeek1.contains(i),
                        onSelected: (_) => _toggle(_preferredWeek1, i),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Preferred days — Week 2',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < _dayNames.length; i++)
                      FilterChip(
                        label: Text(_dayNames[i]),
                        selected: _preferredWeek2.contains(i),
                        onSelected: (_) => _toggle(_preferredWeek2, i),
                      ),
                  ],
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
                if (_staffId != null) ...[
                  const Divider(height: 32),
                  Text(
                    'Unavailability',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  UnavailabilityCalendar(
                    staff: calendarStaff,
                    highlightStaffId: _staffId,
                  ),
                  const SizedBox(height: 16),
                  for (final u in _unavailabilities)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${dateToJson(u.startDate)} – ${dateToJson(u.endDate)}',
                      ),
                      subtitle: u.reason != null ? Text(u.reason!) : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove',
                        onPressed: () => _removeUnavailability(u),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _uaStart ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _uaStart = picked);
                            }
                          },
                          child: Text(
                            _uaStart == null
                                ? 'Start date'
                                : dateToJson(_uaStart!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _uaEnd ?? _uaStart ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => _uaEnd = picked);
                          },
                          child: Text(
                            _uaEnd == null ? 'End date' : dateToJson(_uaEnd!),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _uaReasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _uaStart != null && _uaEnd != null
                        ? _addUnavailability
                        : null,
                    child: const Text('Add Unavailability'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
