import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
import '../../widgets/bulk_add_dialog.dart';
import '../../widgets/confirm_dialog.dart';
import 'room_form_page.dart';

/// Ported from frontend/src/pages/rooms/RoomsListPage.svelte.
class RoomsPage extends StatelessWidget {
  final ApiClient api;

  const RoomsPage({super.key, required this.api});

  Future<void> _openForm(
    BuildContext context,
    VoidCallback reload, {
    Room? existing,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoomFormPage(api: api, existing: existing),
      ),
    );
    if (saved == true) reload();
  }

  /// Unlike the other bulk-adds this one needs a Building, picked once for the whole batch.
  /// [buildings] comes from this page's own load rather than a second fetch. Tags aren't
  /// settable in bulk — they're added per room afterwards via RoomFormPage.
  Future<void> _showBulkForm(
    BuildContext context,
    VoidCallback reload,
    List<Building> buildings,
  ) async {
    final created = await showBulkAddDialog(
      context: context,
      title: 'Bulk Add Rooms',
      entityLabel: 'room',
      entityLabelPlural: 'rooms',
      buildings: buildings,
      submit: (names, buildingId) =>
          api.bulkCreateRooms(buildingId: buildingId!, names: names),
    );
    if (created) reload();
  }

  Future<void> _delete(
    BuildContext context,
    Room room,
    VoidCallback reload,
  ) async {
    if (!await confirmDialog(context, 'Delete room "${room.name}"?')) return;
    try {
      await api.deleteRoom(room.id);
      reload();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete room: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Room names aren't unique across buildings (see RoomFormPage), so the building needs
    // to be in this list too — otherwise same/similarly-named rooms in different buildings
    // are indistinguishable without opening each one's edit form.
    return AsyncLoader<(List<Room>, List<Building>)>(
      load: () async {
        final rooms = await api.listRooms();
        final buildings = await api.listBuildings();
        return (rooms, buildings);
      },
      builder: (context, data, reload) {
        final (rooms, buildings) = data;
        final buildingsById = {for (final b in buildings) b.id: b};
        return Scaffold(
          // These list pages have no AppBar of their own (AppShell owns the only one, and
          // only at phone widths), so bulk-add sits as a small FAB above the single-add one
          // rather than as an app bar action.
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                // Two FABs in one Scaffold otherwise share FloatingActionButton's default
                // hero tag and trip Flutter's duplicate-hero assertion on route
                // transitions.
                heroTag: null,
                onPressed: () => _showBulkForm(context, reload, buildings),
                tooltip: 'Bulk Add Rooms',
                child: const Icon(Icons.playlist_add),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                onPressed: () => _openForm(context, reload),
                tooltip: 'New Room',
                child: const Icon(Icons.add),
              ),
            ],
          ),
          body: rooms.isEmpty
              ? const Center(child: Text('No rooms yet.'))
              : ListView.separated(
                  itemCount: rooms.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    final buildingName =
                        buildingsById[room.buildingId]?.name ?? '—';
                    final tagNames = room.tags.map((t) => t.name).join(', ');
                    return ListTile(
                      title: Text(room.name),
                      subtitle: Text(
                        tagNames.isEmpty
                            ? buildingName
                            : '$buildingName · $tagNames',
                      ),
                      onTap: () => _openForm(context, reload, existing: room),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () => _delete(context, room, reload),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
