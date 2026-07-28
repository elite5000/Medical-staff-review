import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/confirm_dialog.dart';
import 'rule_form_page.dart';

/// Ported from frontend/src/pages/rules/RulesListPage.svelte. Rules have no PATCH endpoint
/// (see backend/app/routers/rules.py) so, matching the Svelte app, there's no edit — only
/// create and delete.
class RulesPage extends StatelessWidget {
  final ApiClient api;

  const RulesPage({super.key, required this.api});

  String _target(Rule rule, Map<int, Building> buildingsById, Map<int, Tag> tagsById) {
    if (rule.buildingId != null) return 'Building: ${buildingsById[rule.buildingId]?.name ?? '—'}';
    if (rule.tagId != null) return 'Tag: ${tagsById[rule.tagId]?.name ?? '—'}';
    return '—';
  }

  Future<void> _openForm(BuildContext context, VoidCallback reload) async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => RuleFormPage(api: api)));
    if (created == true) reload();
  }

  Future<void> _delete(BuildContext context, Rule rule, VoidCallback reload) async {
    if (!await confirmDialog(context, 'Delete rule "${rule.name}"?')) return;
    try {
      await api.deleteRule(rule.id);
      reload();
    } on ApiException catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete rule — it may be referenced by past roster violation history'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncLoader<(List<Rule>, List<Role>, List<Building>, List<Tag>)>(
      load: () async {
        final rules = await api.listRules();
        final roles = await api.listRoles();
        final buildings = await api.listBuildings();
        final tags = await api.listTags();
        return (rules, roles, buildings, tags);
      },
      builder: (context, data, reload) {
        final (rules, roles, buildings, tags) = data;
        final rolesById = {for (final r in roles) r.id: r};
        final buildingsById = {for (final b in buildings) b.id: b};
        final tagsById = {for (final t in tags) t.id: t};

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openForm(context, reload),
            tooltip: 'New Rule',
            child: const Icon(Icons.add),
          ),
          body: rules.isEmpty
              ? const Center(child: Text('No rules yet.'))
              : ListView.separated(
                  itemCount: rules.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final rule = rules[index];
                    final typeLabel = rule.ruleType == RuleType.minimumCount
                        ? 'Minimum count'
                        : 'Eligibility restriction';
                    return ListTile(
                      title: Text(rule.name),
                      subtitle: Text(
                        '$typeLabel · Role: ${rolesById[rule.roleId]?.name ?? '—'} · '
                        '${_target(rule, buildingsById, tagsById)}'
                        '${rule.minimumCount != null ? ' · Min: ${rule.minimumCount}' : ''}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () => _delete(context, rule, reload),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
