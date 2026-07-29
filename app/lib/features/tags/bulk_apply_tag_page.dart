import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/error_banner.dart';

/// What the search box filters on. Tags attach to Rooms (not Buildings), so [tag] filters
/// rooms by their *attached* tag names — it has nothing to do with the tag being applied.
enum SearchMode {
  building('Building'),
  room('Room'),
  tag('Tag');

  final String label;
  const SearchMode(this.label);
}

/// Applies one existing Tag to many Rooms at once.
///
/// Rooms are presented as a Building → Room hierarchy so a whole building can be tagged in
/// one tap while individual rooms stay cherry-pickable. [_selectedRoomIds] is the single
/// source of truth for selection; each building's tri-state checkbox is *derived* from it on
/// every rebuild rather than stored, so the two can never drift apart.
///
/// The apply is additive server-side (POST /tags/{id}/apply-to-rooms unions the tag into each
/// room's existing tags), unlike the single-room edit form, whose save full-replaces them.
class BulkApplyTagPage extends StatefulWidget {
  final ApiClient api;

  const BulkApplyTagPage({super.key, required this.api});

  @override
  State<BulkApplyTagPage> createState() => _BulkApplyTagPageState();
}

class _BulkApplyTagPageState extends State<BulkApplyTagPage> {
  final _searchController = TextEditingController();
  final Set<int> _selectedRoomIds = {};

  /// Which buildings are open. Mutated *without* setState from onExpansionChanged (letting
  /// ExpansionTile animate its own open/close), and *with* setState when the search mode
  /// changes, which forces every tile to rebuild against the new state via its key.
  final Set<int> _expandedBuildingIds = {};

  int? _selectedTagId;
  SearchMode _searchMode = SearchMode.building;
  String _query = '';
  bool _applying = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onModeChanged(SearchMode mode, List<Building> buildings) {
    setState(() {
      _searchMode = mode;
      // A query written for one mode is meaningless in another (a building name rarely
      // matches a room name), so switching modes always starts from a clean box.
      _searchController.clear();
      _query = '';
      _expandedBuildingIds.clear();
      if (mode != SearchMode.building) {
        // Room/Tag searches match *inside* buildings — leaving them collapsed would hide
        // every match behind a manual tap. Building mode is the opposite: collapsing gives
        // a compact list to browse and select whole buildings from.
        _expandedBuildingIds.addAll(buildings.map((b) => b.id));
      }
    });
  }

  /// Rooms of [buildings] that survive the current search, keyed by building, with buildings
  /// that have nothing left to show dropped entirely.
  List<(Building, List<Room>)> _visibleGroups(
    List<Building> buildings,
    List<Room> rooms,
  ) {
    final roomsByBuilding = <int, List<Room>>{};
    for (final room in rooms) {
      roomsByBuilding.putIfAbsent(room.buildingId, () => []).add(room);
    }
    final query = _query.trim().toLowerCase();
    final groups = <(Building, List<Room>)>[];
    for (final building in buildings) {
      final buildingRooms = roomsByBuilding[building.id] ?? const <Room>[];
      if (query.isEmpty) {
        groups.add((building, buildingRooms));
        continue;
      }
      switch (_searchMode) {
        case SearchMode.building:
          if (building.name.toLowerCase().contains(query)) {
            groups.add((building, buildingRooms));
          }
        case SearchMode.room:
          final matches = buildingRooms
              .where((r) => r.name.toLowerCase().contains(query))
              .toList();
          if (matches.isNotEmpty) groups.add((building, matches));
        case SearchMode.tag:
          final matches = buildingRooms
              .where(
                (r) => r.tags.any((t) => t.name.toLowerCase().contains(query)),
              )
              .toList();
          if (matches.isNotEmpty) groups.add((building, matches));
      }
    }
    return groups;
  }

  /// true = every room selected, false = none, null = some (indeterminate). An empty
  /// building reads as unselected rather than vacuously "all selected".
  bool? _buildingState(List<Room> rooms) {
    if (rooms.isEmpty) return false;
    final selected = rooms.where((r) => _selectedRoomIds.contains(r.id)).length;
    if (selected == 0) return false;
    if (selected == rooms.length) return true;
    return null;
  }

  /// Operates on the rooms currently *visible* under the building, not every room it owns —
  /// with a search active, tapping the header must never quietly select filtered-out rooms.
  void _toggleBuilding(List<Room> rooms) {
    if (rooms.isEmpty) return;
    setState(() {
      if (_buildingState(rooms) == true) {
        _selectedRoomIds.removeAll(rooms.map((r) => r.id));
      } else {
        // Partly-selected buildings fill up rather than empty out.
        _selectedRoomIds.addAll(rooms.map((r) => r.id));
      }
    });
  }

  void _toggleRoom(int roomId) {
    setState(() {
      if (!_selectedRoomIds.remove(roomId)) _selectedRoomIds.add(roomId);
    });
  }

  Future<void> _apply(List<Tag> tags, VoidCallback reload) async {
    final tagId = _selectedTagId;
    if (tagId == null || _selectedRoomIds.isEmpty) return;
    setState(() {
      _applying = true;
      _error = null;
    });
    final roomCount = _selectedRoomIds.length;
    try {
      await widget.api.applyTagToRooms(tagId, _selectedRoomIds.toList());
      if (!mounted) return;
      setState(() => _applying = false);
      // Refetch so every room's chips show the tag it just gained. _selectedRoomIds is
      // deliberately left intact: applying is not "finishing", and keeping the selection lets
      // the same set of rooms be given a second tag without rebuilding it by hand. The Clear
      // selection button is the only thing that empties it.
      reload();
      final tagName = tags
          .where((t) => t.id == tagId)
          .map((t) => t.name)
          .firstOrNull;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Applied "${tagName ?? 'tag'}" to $roomCount '
            '${roomCount == 1 ? 'room' : 'rooms'}.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _applying = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Apply Tag to Rooms')),
      body: AsyncLoader<(List<Building>, List<Room>, List<Tag>)>(
        load: () async {
          final buildings = await widget.api.listBuildings();
          final rooms = await widget.api.listRooms();
          final tags = await widget.api.listTags();
          return (buildings, rooms, tags);
        },
        builder: (context, data, reload) {
          final (buildings, rooms, tags) = data;
          final groups = _visibleGroups(buildings, rooms);
          // The post-apply refetch re-reads /tags, so a tag deleted on another device could
          // leave _selectedTagId pointing at nothing — which DropdownButtonFormField asserts
          // on. Fall back to "no tag chosen", which also disables Apply.
          final selectedTagId = tags.any((t) => t.id == _selectedTagId)
              ? _selectedTagId
              : null;
          final canApply =
              selectedTagId != null &&
              _selectedRoomIds.isNotEmpty &&
              !_applying;

          return Column(
            children: [
              ErrorBanner(message: _error),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      key: const Key('tag-picker'),
                      initialValue: selectedTagId,
                      decoration: const InputDecoration(labelText: 'Tag'),
                      items: tags
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(t.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedTagId = value),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('search-field'),
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Search ${_searchMode.label}',
                              prefixIcon: const Icon(Icons.search),
                              isDense: true,
                            ),
                            onChanged: (value) =>
                                setState(() => _query = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SegmentedButton<SearchMode>(
                          segments: SearchMode.values
                              .map(
                                (m) => ButtonSegment(
                                  value: m,
                                  label: Text(m.label),
                                ),
                              )
                              .toList(),
                          selected: {_searchMode},
                          showSelectedIcon: false,
                          onSelectionChanged: (selection) =>
                              _onModeChanged(selection.first, buildings),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: groups.isEmpty
                    ? Center(
                        child: Text(
                          rooms.isEmpty
                              ? 'No rooms yet.'
                              : 'No matches for this search.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final (building, buildingRooms) = groups[index];
                          return _buildingTile(building, buildingRooms);
                        },
                      ),
              ),
              const Divider(height: 1),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedRoomIds.length} '
                          '${_selectedRoomIds.length == 1 ? 'room' : 'rooms'} selected',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: _selectedRoomIds.isEmpty
                            ? null
                            : () => setState(_selectedRoomIds.clear),
                        child: const Text('Clear selection'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: canApply ? () => _apply(tags, reload) : null,
                        child: _applying
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Apply'),
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

  Widget _buildingTile(Building building, List<Room> rooms) {
    final expanded = _expandedBuildingIds.contains(building.id);
    final selectedCount = rooms
        .where((r) => _selectedRoomIds.contains(r.id))
        .length;
    return ExpansionTile(
      // Folding the desired state into the key is what lets a search-mode switch expand or
      // collapse every building at once: ExpansionTile only reads initiallyExpanded when its
      // State is first created, so the changed key forces a fresh one.
      key: ValueKey('building-${building.id}-$expanded'),
      initiallyExpanded: expanded,
      onExpansionChanged: (isExpanded) {
        // No setState — the tile is already animating itself, and rebuilding mid-animation
        // would cut it short. The value only needs to be right for the *next* rebuild.
        if (isExpanded) {
          _expandedBuildingIds.add(building.id);
        } else {
          _expandedBuildingIds.remove(building.id);
        }
      },
      leading: Checkbox(
        key: Key('building-checkbox-${building.id}'),
        tristate: true,
        value: _buildingState(rooms),
        onChanged: rooms.isEmpty ? null : (_) => _toggleBuilding(rooms),
      ),
      title: Text(building.name),
      subtitle: Text('$selectedCount of ${rooms.length} selected'),
      children: [
        for (final room in rooms)
          CheckboxListTile(
            key: Key('room-checkbox-${room.id}'),
            value: _selectedRoomIds.contains(room.id),
            onChanged: (_) => _toggleRoom(room.id),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            title: Text(room.name),
            subtitle: room.tags.isEmpty
                ? null
                : Wrap(
                    spacing: 4,
                    children: [
                      for (final tag in room.tags)
                        Chip(
                          label: Text(tag.name),
                          labelStyle: Theme.of(context).textTheme.labelSmall,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }
}
