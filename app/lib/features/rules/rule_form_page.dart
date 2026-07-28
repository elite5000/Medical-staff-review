import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/error_banner.dart';

enum _TargetType { building, tag }

/// Ported from frontend/src/pages/rules/RuleFormPage.svelte. Create-only — see rules_page's
/// note on why there's no edit flow.
class RuleFormPage extends StatefulWidget {
  final ApiClient api;

  const RuleFormPage({super.key, required this.api});

  @override
  State<RuleFormPage> createState() => _RuleFormPageState();
}

class _RuleFormPageState extends State<RuleFormPage> {
  final _nameController = TextEditingController();
  final _minimumCountController = TextEditingController(text: '1');
  RuleType _ruleType = RuleType.minimumCount;
  _TargetType _targetType = _TargetType.building;
  int? _roleId;
  int? _buildingId;
  int? _tagId;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _minimumCountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_roleId == null) {
      setState(() => _error = 'A role is required');
      return;
    }
    // Directly changes a solver constraint, so an unparseable/cleared field must not
    // silently fall back to a default (1) and submit anyway — the admin would have no idea
    // the value they typed wasn't what actually got saved.
    int? minimumCount;
    if (_ruleType == RuleType.minimumCount) {
      minimumCount = int.tryParse(_minimumCountController.text.trim());
      if (minimumCount == null || minimumCount < 1) {
        setState(
          () => _error = 'Minimum count must be a whole number of at least 1',
        );
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_ruleType == RuleType.eligibilityRestriction) {
        await widget.api.createRule(
          name: _nameController.text.trim(),
          ruleType: _ruleType,
          roleId: _roleId!,
          tagId: _tagId,
        );
      } else {
        await widget.api.createRule(
          name: _nameController.text.trim(),
          ruleType: _ruleType,
          roleId: _roleId!,
          minimumCount: minimumCount,
          buildingId: _targetType == _TargetType.building ? _buildingId : null,
          tagId: _targetType == _TargetType.tag ? _tagId : null,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Rule')),
      body: AsyncLoader<(List<Role>, List<Building>, List<Tag>)>(
        load: () async {
          final roles = await widget.api.listRoles();
          final buildings = await widget.api.listBuildings();
          final tags = await widget.api.listTags();
          _roleId ??= roles.firstOrNull?.id;
          _buildingId ??= buildings.firstOrNull?.id;
          _tagId ??= tags.firstOrNull?.id;
          return (roles, buildings, tags);
        },
        builder: (context, data, _) {
          final (roles, buildings, tags) = data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ErrorBanner(message: _error),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RuleType>(
                initialValue: _ruleType,
                decoration: const InputDecoration(labelText: 'Rule type'),
                items: const [
                  DropdownMenuItem(
                    value: RuleType.minimumCount,
                    child: Text('Minimum count'),
                  ),
                  DropdownMenuItem(
                    value: RuleType.eligibilityRestriction,
                    child: Text('Eligibility restriction'),
                  ),
                ],
                onChanged: (value) => setState(() => _ruleType = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _roleId,
                decoration: const InputDecoration(labelText: 'Role'),
                items: roles
                    .map(
                      (r) => DropdownMenuItem(value: r.id, child: Text(r.name)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _roleId = value),
              ),
              const SizedBox(height: 16),
              if (_ruleType == RuleType.minimumCount) ...[
                DropdownButtonFormField<_TargetType>(
                  initialValue: _targetType,
                  decoration: const InputDecoration(labelText: 'Applies to'),
                  items: const [
                    DropdownMenuItem(
                      value: _TargetType.building,
                      child: Text('Building'),
                    ),
                    DropdownMenuItem(
                      value: _TargetType.tag,
                      child: Text('Tag'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _targetType = value!),
                ),
                const SizedBox(height: 16),
                // Distinct Keys matter: without them, Flutter reuses the same FormFieldState
                // across the Building<->Tag swap (same widget type, same tree position), so
                // the dropdown keeps showing the previous target type's stale selected value
                // — which usually isn't a valid id in the new items list.
                if (_targetType == _TargetType.building)
                  DropdownButtonFormField<int>(
                    key: const ValueKey('applies-to-building'),
                    initialValue: _buildingId,
                    decoration: const InputDecoration(labelText: 'Building'),
                    items: buildings
                        .map(
                          (b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _buildingId = value),
                  )
                else
                  DropdownButtonFormField<int>(
                    key: const ValueKey('applies-to-tag'),
                    initialValue: _tagId,
                    decoration: const InputDecoration(labelText: 'Tag'),
                    items: tags
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _tagId = value),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _minimumCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minimum count'),
                ),
              ] else
                DropdownButtonFormField<int>(
                  initialValue: _tagId,
                  decoration: const InputDecoration(labelText: 'Tag'),
                  items: tags
                      .map(
                        (t) =>
                            DropdownMenuItem(value: t.id, child: Text(t.name)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _tagId = value),
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
            ],
          );
        },
      ),
    );
  }
}
