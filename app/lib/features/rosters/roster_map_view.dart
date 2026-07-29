import 'dart:math';

import 'package:flutter/material.dart';

import '../../api/models.dart';
import 'corridor_room_map.dart';
import 'shift_calendar.dart';

enum _MapLevel { buildings, rooms, calendar }

class RosterMapView extends StatefulWidget {
  final RosterDetail roster;
  final RosterLookups lookups;

  const RosterMapView({super.key, required this.roster, required this.lookups});

  @override
  State<RosterMapView> createState() => _RosterMapViewState();
}

class _RosterMapViewState extends State<RosterMapView> {
  _MapLevel _level = _MapLevel.buildings;
  int? _selectedBuildingId;
  int? _selectedRoomId;

  void _drillIntoBuilding(int id) => setState(() {
    _selectedBuildingId = id;
    _level = _MapLevel.rooms;
  });

  void _drillIntoRoom(int id) => setState(() {
    _selectedRoomId = id;
    _level = _MapLevel.calendar;
  });

  void _back() => setState(() {
    if (_level == _MapLevel.calendar) {
      _selectedRoomId = null;
      _level = _MapLevel.rooms;
    } else if (_level == _MapLevel.rooms) {
      _selectedBuildingId = null;
      _level = _MapLevel.buildings;
    }
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              if (_level != _MapLevel.buildings)
                IconButton(
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back),
                ),
              Text(
                _breadcrumbLabel(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_level) {
            _MapLevel.buildings => _buildBuildingsGrid(context),
            _MapLevel.rooms => CorridorRoomMap(
              rooms: widget.lookups.rooms
                  .where((r) => r.buildingId == _selectedBuildingId)
                  .toList(),
              onRoomTap: _drillIntoRoom,
            ),
            _MapLevel.calendar => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: TwoWeekShiftCalendar(
                entries: buildShiftDisplayEntries(
                  widget.roster.shifts.where(
                    (s) => s.roomId == _selectedRoomId,
                  ),
                  widget.lookups,
                ),
                rangeStart: widget.roster.startDate,
                rangeEnd: widget.roster.endDate,
              ),
            ),
          },
        ),
      ],
    );
  }

  String _breadcrumbLabel() {
    switch (_level) {
      case _MapLevel.buildings:
        return 'Buildings';
      case _MapLevel.rooms:
        return widget.lookups.buildingsById[_selectedBuildingId]?.name ??
            'Building';
      case _MapLevel.calendar:
        final building =
            widget.lookups.buildingsById[_selectedBuildingId]?.name ??
            'Building';
        final room = widget.lookups.roomsById[_selectedRoomId]?.name ?? 'Room';
        return '$building > $room';
    }
  }

  Widget _buildBuildingsGrid(BuildContext context) {
    final buildings = widget.lookups.buildings;
    if (buildings.isEmpty) {
      return const Center(child: Text('No buildings yet.'));
    }

    final columns = sqrt(buildings.length).ceil();
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
      ),
      itemCount: buildings.length,
      itemBuilder: (context, i) {
        final building = buildings[i];
        return InkWell(
          onTap: () => _drillIntoBuilding(building.id),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.apartment, size: 36),
              ),
              const SizedBox(height: 4),
              Text(building.name, textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }
}
