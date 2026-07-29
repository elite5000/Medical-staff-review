import 'package:flutter/material.dart';

import '../../api/models.dart';

const double _tileSize = 80;
const double _tileSpacing = 8;

/// Lays out a building's rooms as corridors of up to 8 rooms each: 4 inside a bordered
/// "hallway" rectangle, 2 outside along the top edge, 2 outside along the bottom edge.
/// Extra rooms spill into additional corridors chained to the right.
class CorridorRoomMap extends StatelessWidget {
  final List<Room> rooms;
  final ValueChanged<int> onRoomTap;

  const CorridorRoomMap({super.key, required this.rooms, required this.onRoomTap});

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const Center(child: Text('No rooms in this building yet.'));
    }

    final corridorCount = (rooms.length / 8).ceil();
    final corridors = List.generate(
      corridorCount,
      (i) => rooms.skip(i * 8).take(8).toList(),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final (i, corridorRooms) in corridors.indexed) ...[
              if (i > 0)
                Container(
                  width: 24,
                  height: 2,
                  color: Theme.of(context).dividerColor,
                ),
              _CorridorUnit(rooms: corridorRooms, onRoomTap: onRoomTap),
            ],
          ],
        ),
      ),
    );
  }
}

class _CorridorUnit extends StatelessWidget {
  final List<Room> rooms;
  final ValueChanged<int> onRoomTap;

  const _CorridorUnit({required this.rooms, required this.onRoomTap});

  @override
  Widget build(BuildContext context) {
    final inside = rooms.take(4).toList();
    final remaining = rooms.skip(4).toList();
    final top = remaining.take(2).toList();
    final bottom = remaining.skip(2).take(2).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (top.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: top.map((r) => _RoomTile(room: r, onTap: onRoomTap)).toList(),
          ),
        Container(
          padding: const EdgeInsets.all(_tileSpacing),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: inside.map((r) => _RoomTile(room: r, onTap: onRoomTap)).toList(),
          ),
        ),
        if (bottom.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: bottom.map((r) => _RoomTile(room: r, onTap: onRoomTap)).toList(),
          ),
      ],
    );
  }
}

class _RoomTile extends StatelessWidget {
  final Room room;
  final ValueChanged<int> onTap;

  const _RoomTile({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(room.id),
      child: Container(
        width: _tileSize,
        height: _tileSize,
        margin: const EdgeInsets.all(_tileSpacing / 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.primary),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          room.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
