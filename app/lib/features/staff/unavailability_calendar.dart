import 'package:flutter/material.dart';

import '../../api/models.dart';

/// Ported from frontend/src/lib/components/UnavailabilityCalendar.svelte: a month grid
/// showing every staff member's unavailable days as colored dots, so gaps/overlaps are
/// visible at a glance while editing one staff member's own unavailability below it.
class UnavailabilityCalendar extends StatefulWidget {
  final List<Staff> staff;
  final int? highlightStaffId;

  const UnavailabilityCalendar({
    super.key,
    required this.staff,
    this.highlightStaffId,
  });

  @override
  State<UnavailabilityCalendar> createState() => _UnavailabilityCalendarState();
}

class _UnavailabilityCalendarState extends State<UnavailabilityCalendar> {
  late DateTime _viewMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(
      () => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta),
    );
  }

  // Golden-angle-ish spread keeps adjacent staff ids visually distinct.
  Color _colorFor(int id) =>
      HSLColor.fromAHSL(1, (id * 137) % 360, 0.65, 0.45).toColor();

  Map<int, List<Staff>> _unavailableByDay() {
    final map = <int, List<Staff>>{};
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final monthStart = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final monthEnd = DateTime(_viewMonth.year, _viewMonth.month, daysInMonth);
    for (final person in widget.staff) {
      for (final u in person.unavailabilities) {
        final start = u.startDate.isBefore(monthStart)
            ? monthStart
            : u.startDate;
        final end = u.endDate.isAfter(monthEnd) ? monthEnd : u.endDate;
        if (start.isAfter(end)) continue;
        for (var day = start.day; day <= end.day; day++) {
          if (start.month != _viewMonth.month) continue;
          (map[day] ??= []).add(person);
        }
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final firstOfMonth = DateTime(_viewMonth.year, _viewMonth.month, 1);
    // Monday-first: DateTime.weekday is 1=Mon..7=Sun already.
    final leadingBlanks = firstOfMonth.weekday - 1;
    final cells = <int?>[
      ...List.filled(leadingBlanks, null),
      ...List.generate(daysInMonth, (i) => i + 1),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final unavailableByDay = _unavailableByDay();
    final legendStaff = widget.staff
        .where((s) => unavailableByDay.values.any((list) => list.contains(s)))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => _shiftMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${_monthName(_viewMonth.month)} ${_viewMonth.year}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              onPressed: () => _shiftMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: cells.length,
          itemBuilder: (context, index) {
            final day = cells[index];
            if (day == null) return const SizedBox.shrink();
            final entries = unavailableByDay[day] ?? const [];
            return Container(
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text('$day', style: Theme.of(context).textTheme.bodySmall),
                  Wrap(
                    spacing: 2,
                    children: entries
                        .map(
                          (person) => Tooltip(
                            message: person.name,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _colorFor(person.id),
                                shape: BoxShape.circle,
                                border: person.id == widget.highlightStaffId
                                    ? Border.all(
                                        color: Colors.black,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            );
          },
        ),
        if (legendStaff.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: legendStaff
                  .map(
                    (person) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _colorFor(person.id),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          person.name,
                          style: person.id == widget.highlightStaffId
                              ? const TextStyle(fontWeight: FontWeight.bold)
                              : null,
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];
}
