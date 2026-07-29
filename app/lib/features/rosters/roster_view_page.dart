import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/error_banner.dart';
import 'roster_map_view.dart';
import 'roster_personal_view.dart';
import 'shift_calendar.dart';

typedef _RosterViewData = (
  RosterDetail,
  List<Room>,
  List<Staff>,
  List<Building>,
  List<Tag>,
  List<Roster>,
  AppSettings,
);

enum _ViewMode { text, personal, map }

/// Ported from frontend/src/pages/rosters/RosterViewPage.svelte.
class RosterViewPage extends StatefulWidget {
  final ApiClient api;
  final int rosterId;

  const RosterViewPage({super.key, required this.api, required this.rosterId});

  @override
  State<RosterViewPage> createState() => _RosterViewPageState();
}

class _RosterViewPageState extends State<RosterViewPage> {
  String? _error;
  _ViewMode _viewMode = _ViewMode.text;

  Future<_RosterViewData> _load() async {
    final roster = await widget.api.getRoster(widget.rosterId);
    final rooms = await widget.api.listRooms();
    final staff = await widget.api.listStaff();
    final buildings = await widget.api.listBuildings();
    final tags = await widget.api.listTags();
    final rosters = await widget.api.listRosters();
    final settings = await widget.api.getSettings();
    return (roster, rooms, staff, buildings, tags, rosters, settings);
  }

  // Only the latest generation for a date range is editable — matches RostersPage's
  // _latestIdsByRange and the backend's own _is_latest_for_range check, which rejects edits
  // to older generations regardless of what this shows.
  bool _isLatestForRange(RosterDetail roster, List<Roster> rosters) {
    return !rosters.any(
      (r) =>
          r.startDate == roster.startDate &&
          r.endDate == roster.endDate &&
          r.generatedAt.isAfter(roster.generatedAt),
    );
  }

  Map<DateTime, List<Shift>> _shiftsByDate(
    RosterDetail roster,
    Map<int, Room> roomsById,
  ) {
    final groups = <DateTime, List<Shift>>{};
    for (final shift in roster.shifts) {
      (groups[shift.date] ??= []).add(shift);
    }
    for (final list in groups.values) {
      list.sort((a, b) {
        final roomA = roomsById[a.roomId]?.name ?? '';
        final roomB = roomsById[b.roomId]?.name ?? '';
        final byRoom = roomA.compareTo(roomB);
        return byRoom != 0 ? byRoom : a.shiftIndex.compareTo(b.shiftIndex);
      });
    }
    return groups;
  }

  String _violationLabel(
    RosterViolation v,
    Map<int, Room> roomsById,
    Map<int, Building> buildingsById,
    Map<int, Tag> tagsById,
  ) {
    if (v.violationType == ViolationType.roomUnfilled) {
      final room = v.roomId != null ? roomsById[v.roomId]?.name : null;
      return '${room ?? 'Room'} unfilled on ${dateToJson(v.date)} (shift ${v.shiftIndex})';
    }
    final scope = v.buildingId != null
        ? 'Building: ${buildingsById[v.buildingId]?.name ?? '—'}'
        : v.tagId != null
        ? 'Tag: ${tagsById[v.tagId]?.name ?? '—'}'
        : '—';
    return 'Minimum-count rule unmet for $scope on ${dateToJson(v.date)} (shift ${v.shiftIndex}) — ${v.detail ?? ''}';
  }

  Future<void> _reassign(Shift shift, int staffId, VoidCallback reload) async {
    setState(() => _error = null);
    try {
      await widget.api.updateShift(widget.rosterId, shift.id, staffId: staffId);
      reload();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Widget _buildTextView(
    BuildContext context,
    RosterDetail roster,
    RosterLookups lookups,
    List<Tag> tags,
    List<Roster> rosters,
    VoidCallback reload,
  ) {
    final tagsById = {for (final t in tags) t.id: t};
    final isLatest = _isLatestForRange(roster, rosters);
    final shiftsByDate = _shiftsByDate(roster, lookups.roomsById);
    final sortedDates = shiftsByDate.keys.toList()..sort();

    return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ErrorBanner(message: _error),
              Text(
                '${dateToJson(roster.startDate)} – ${dateToJson(roster.endDate)} (generated ${roster.generatedAt})',
              ),
              if (roster.violations.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Violations',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final v in roster.violations)
                  Text(
                    '• ${_violationLabel(v, lookups.roomsById, lookups.buildingsById, tagsById)}',
                  ),
              ],
              for (final date in sortedDates) ...[
                const SizedBox(height: 16),
                Text(
                  dateToJson(date),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                for (final shift in shiftsByDate[date]!)
                  Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      title: Text(
                        '${lookups.roomsById[shift.roomId]?.name ?? '—'} · shift ${shift.shiftIndex}',
                      ),
                      subtitle: Text('Pinned: ${shift.pinned ? 'Yes' : 'No'}'),
                      trailing: isLatest
                          ? DropdownButton<int>(
                              value: shift.staffId,
                              items: lookups.staff
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _reassign(shift, value, reload);
                                }
                              },
                            )
                          : Text(
                              lookups.staffById[shift.staffId]?.name ??
                                  '${shift.staffId}',
                            ),
                    ),
                  ),
      ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Roster')),
      body: AsyncLoader<_RosterViewData>(
        load: _load,
        builder: (context, data, reload) {
          final (roster, rooms, staff, buildings, tags, rosters, settings) =
              data;
          final lookups = RosterLookups(
            rooms: rooms,
            buildings: buildings,
            staff: staff,
            settings: settings,
          );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: SegmentedButton<_ViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: _ViewMode.text,
                      label: Text('Text'),
                      icon: Icon(Icons.list),
                    ),
                    ButtonSegment(
                      value: _ViewMode.personal,
                      label: Text('Personal'),
                      icon: Icon(Icons.person),
                    ),
                    ButtonSegment(
                      value: _ViewMode.map,
                      label: Text('Map'),
                      icon: Icon(Icons.map),
                    ),
                  ],
                  selected: {_viewMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selected) =>
                      setState(() => _viewMode = selected.first),
                ),
              ),
              Expanded(
                child: switch (_viewMode) {
                  _ViewMode.text => _buildTextView(
                    context,
                    roster,
                    lookups,
                    tags,
                    rosters,
                    reload,
                  ),
                  _ViewMode.personal => RosterPersonalView(
                    roster: roster,
                    lookups: lookups,
                  ),
                  _ViewMode.map => RosterMapView(
                    roster: roster,
                    lookups: lookups,
                  ),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
