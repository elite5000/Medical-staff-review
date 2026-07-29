import 'package:flutter/material.dart';

import '../../api/models.dart';
import 'shift_calendar.dart';

class RosterPersonalView extends StatefulWidget {
  final RosterDetail roster;
  final RosterLookups lookups;

  const RosterPersonalView({
    super.key,
    required this.roster,
    required this.lookups,
  });

  @override
  State<RosterPersonalView> createState() => _RosterPersonalViewState();
}

class _RosterPersonalViewState extends State<RosterPersonalView> {
  int? _selectedStaffId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Autocomplete<Staff>(
            displayStringForOption: (s) => s.name,
            optionsBuilder: (value) {
              if (value.text.isEmpty) return widget.lookups.staff;
              final query = value.text.toLowerCase();
              return widget.lookups.staff.where(
                (s) => s.name.toLowerCase().contains(query),
              );
            },
            onSelected: (s) => setState(() => _selectedStaffId = s.id),
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Search staff',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
          ),
          const SizedBox(height: 16),
          if (_selectedStaffId == null)
            const Expanded(
              child: Center(
                child: Text('Pick a staff member to see their roster.'),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: TwoWeekShiftCalendar(
                  entries: buildShiftDisplayEntries(
                    widget.roster.shifts.where(
                      (s) => s.staffId == _selectedStaffId,
                    ),
                    widget.lookups,
                  ),
                  rangeStart: widget.roster.startDate,
                  rangeEnd: widget.roster.endDate,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
