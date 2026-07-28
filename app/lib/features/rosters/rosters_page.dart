import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import 'roster_generate_page.dart';
import 'roster_view_page.dart';

/// Every generation is retained permanently (see CONTEXT.md's Roster entry) — only the
/// most recent generation for a given date range gets a "Regenerate" action; older
/// generations for the same range are viewable read-only history.
Set<int> _latestIdsByRange(List<Roster> rosters) {
  final latest = <String, Roster>{};
  for (final roster in rosters) {
    final key = '${roster.startDate}_${roster.endDate}';
    final current = latest[key];
    if (current == null || roster.generatedAt.isAfter(current.generatedAt)) {
      latest[key] = roster;
    }
  }
  return latest.values.map((r) => r.id).toSet();
}

/// Ported from frontend/src/pages/rosters/RosterListPage.svelte.
class RostersPage extends StatefulWidget {
  final ApiClient api;

  const RostersPage({super.key, required this.api});

  @override
  State<RostersPage> createState() => _RostersPageState();
}

class _RostersPageState extends State<RostersPage> {
  int? _regeneratingRosterId;

  Future<void> _generate(BuildContext context, VoidCallback reload) async {
    final generated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RosterGeneratePage(api: widget.api)),
    );
    if (generated == true) reload();
  }

  Future<void> _view(BuildContext context, Roster roster) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RosterViewPage(api: widget.api, rosterId: roster.id),
      ),
    );
  }

  Future<void> _regenerate(
    BuildContext context,
    Roster roster,
    VoidCallback reload,
  ) async {
    if (_regeneratingRosterId != null) return;
    setState(() => _regeneratingRosterId = roster.id);
    try {
      await widget.api.regenerateRoster(roster.id);
      reload();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not regenerate roster: ${e.message}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _regeneratingRosterId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncLoader<List<Roster>>(
      load: widget.api.listRosters,
      builder: (context, rosters, reload) {
        final latestIds = _latestIdsByRange(rosters);
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _generate(context, reload),
            icon: const Icon(Icons.add),
            label: const Text('Generate Roster'),
          ),
          body: rosters.isEmpty
              ? const Center(child: Text('No rosters yet.'))
              : ListView.separated(
                  itemCount: rosters.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final roster = rosters[index];
                    return ListTile(
                      title: Text(
                        '${dateToJson(roster.startDate)} – ${dateToJson(roster.endDate)}',
                      ),
                      subtitle: Text(
                        'Generated ${roster.generatedAt} · '
                        'Violations: ${roster.hasViolations ? 'Yes' : 'No'}',
                      ),
                      onTap: () => _view(context, roster),
                      trailing: latestIds.contains(roster.id)
                          ? TextButton(
                              onPressed: _regeneratingRosterId == null
                                  ? () => _regenerate(context, roster, reload)
                                  : null,
                              child: _regeneratingRosterId == roster.id
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Regenerate'),
                            )
                          : null,
                    );
                  },
                ),
        );
      },
    );
  }
}
