import 'package:flutter/material.dart';

import '../../api/models.dart';
import 'shift_timing.dart';

/// Shifts reference rooms/buildings/staff only by id; this bundles the id -> object
/// lookups (plus settings, needed alongside them for shiftWindowMinutes) built once per
/// roster load, so each view (text/personal/map) doesn't rebuild the same maps.
class RosterLookups {
  final List<Room> rooms;
  final List<Building> buildings;
  final List<Staff> staff;
  final AppSettings settings;
  final Map<int, Room> roomsById;
  final Map<int, Building> buildingsById;
  final Map<int, Staff> staffById;

  RosterLookups({
    required this.rooms,
    required this.buildings,
    required this.staff,
    required this.settings,
  }) : roomsById = {for (final r in rooms) r.id: r},
       buildingsById = {for (final b in buildings) b.id: b},
       staffById = {for (final s in staff) s.id: s};
}

class ShiftDisplayEntry {
  final DateTime date;
  final int startMinutes;
  final int endMinutes;
  final String label;

  ShiftDisplayEntry({
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    required this.label,
  });
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Turns a (already filtered, e.g. by staffId or roomId) set of shifts into display
/// entries labeled "{building} - {room} - {staff}" with real clock times, via
/// shiftWindowMinutes.
List<ShiftDisplayEntry> buildShiftDisplayEntries(
  Iterable<Shift> shifts,
  RosterLookups lookups,
) {
  return shifts.map((shift) {
    final room = lookups.roomsById[shift.roomId];
    final building = room != null ? lookups.buildingsById[room.buildingId] : null;
    final (start, end) = building != null
        ? shiftWindowMinutes(shift, building, lookups.settings)
        : (0, 0);
    return ShiftDisplayEntry(
      date: _dateOnly(shift.date),
      startMinutes: start,
      endMinutes: end,
      label:
          '${building?.name ?? '—'} - ${room?.name ?? '—'} - '
          '${lookups.staffById[shift.staffId]?.name ?? '—'}',
    );
  }).toList();
}

const _weekdayAbbrev = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// A 2-week, paginated grid of appointment blocks. [rangeStart]/[rangeEnd] are both
/// INCLUSIVE (matching Roster.startDate/endDate) — pagination stays within that range,
/// disabling prev/next at the edges.
class TwoWeekShiftCalendar extends StatefulWidget {
  final List<ShiftDisplayEntry> entries;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  const TwoWeekShiftCalendar({
    super.key,
    required this.entries,
    required this.rangeStart,
    required this.rangeEnd,
  });

  @override
  State<TwoWeekShiftCalendar> createState() => _TwoWeekShiftCalendarState();
}

class _TwoWeekShiftCalendarState extends State<TwoWeekShiftCalendar> {
  late DateTime _pageStart;

  @override
  void initState() {
    super.initState();
    _pageStart = _dateOnly(widget.rangeStart);
  }

  @override
  void didUpdateWidget(TwoWeekShiftCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dateOnly(oldWidget.rangeStart).isAtSameMomentAs(
      _dateOnly(widget.rangeStart),
    )) {
      _pageStart = _dateOnly(widget.rangeStart);
    }
  }

  bool get _canGoPrev => _pageStart.isAfter(_dateOnly(widget.rangeStart));

  bool get _canGoNext =>
      !_pageStart
          .add(const Duration(days: 14))
          .isAfter(_dateOnly(widget.rangeEnd));

  void _shiftPage(int deltaPages) {
    setState(
      () => _pageStart = _pageStart.add(Duration(days: 14 * deltaPages)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesByDate = <DateTime, List<ShiftDisplayEntry>>{};
    for (final entry in widget.entries) {
      (entriesByDate[entry.date] ??= []).add(entry);
    }
    for (final list in entriesByDate.values) {
      list.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    }

    final pageEnd = _pageStart.add(const Duration(days: 13));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _canGoPrev ? () => _shiftPage(-1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${dateToJson(_pageStart)} – ${dateToJson(pageEnd)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              onPressed: _canGoNext ? () => _shiftPage(1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 170,
          ),
          itemCount: 14,
          itemBuilder: (context, i) {
            final date = _pageStart.add(Duration(days: i));
            final dayEntries = entriesByDate[date] ?? const [];
            return Container(
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_weekdayAbbrev[date.weekday - 1]} ${date.day}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Expanded(
                    child: dayEntries.isEmpty
                        ? const SizedBox.shrink()
                        : ListView(
                            padding: EdgeInsets.zero,
                            children: dayEntries
                                .map(
                                  (e) => Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 1,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Text(
                                        '${formatClockMinutes(e.startMinutes, wrap: true)}–'
                                        '${formatClockMinutes(e.endMinutes, wrap: true)}\n'
                                        '${e.label}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
