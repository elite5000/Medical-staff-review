import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/models.dart';
import '../../widgets/async_loader.dart';
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
    return AsyncLoader<List<Room>>(
      load: api.listRooms,
      builder: (context, rooms, reload) => Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openForm(context, reload),
          tooltip: 'New Room',
          child: const Icon(Icons.add),
        ),
        body: rooms.isEmpty
            ? const Center(child: Text('No rooms yet.'))
            : ListView.separated(
                itemCount: rooms.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  return ListTile(
                    title: Text(room.name),
                    subtitle: room.tags.isEmpty
                        ? null
                        : Text(room.tags.map((t) => t.name).join(', ')),
                    onTap: () => _openForm(context, reload, existing: room),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () => _delete(context, room, reload),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
