import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'features/buildings/buildings_page.dart';
import 'features/roles/roles_page.dart';
import 'features/rooms/rooms_page.dart';
import 'features/rosters/rosters_page.dart';
import 'features/rules/rules_page.dart';
import 'features/settings/settings_page.dart';
import 'features/staff/staff_page.dart';
import 'features/tags/tags_page.dart';

class _Destination {
  final String label;
  final IconData icon;
  final Widget Function(ApiClient) buildPage;

  const _Destination({required this.label, required this.icon, required this.buildPage});
}

/// Adaptive navigation shell wrapping every resource screen: a NavigationRail on
/// desktop/tablet-width windows, a bottom NavigationBar on phone widths — same set of
/// destinations either way, so the CRUD screens underneath don't need to know which shell
/// they're hosted in.
class AppShell extends StatefulWidget {
  final ApiClient api;

  const AppShell({super.key, required this.api});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static final _destinations = <_Destination>[
    _Destination(
      label: 'Rosters',
      icon: Icons.calendar_month,
      buildPage: (api) => RostersPage(api: api),
    ),
    _Destination(label: 'Staff', icon: Icons.people, buildPage: (api) => StaffPage(api: api)),
    _Destination(
      label: 'Buildings',
      icon: Icons.apartment,
      buildPage: (api) => BuildingsPage(api: api),
    ),
    _Destination(label: 'Rooms', icon: Icons.meeting_room, buildPage: (api) => RoomsPage(api: api)),
    _Destination(label: 'Tags', icon: Icons.label, buildPage: (api) => TagsPage(api: api)),
    _Destination(label: 'Roles', icon: Icons.badge, buildPage: (api) => RolesPage(api: api)),
    _Destination(label: 'Rules', icon: Icons.rule, buildPage: (api) => RulesPage(api: api)),
    _Destination(
      label: 'Settings',
      icon: Icons.settings,
      buildPage: (api) => SettingsPage(api: api),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final page = _destinations[_selectedIndex].buildPage(widget.api);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                  labelType: NavigationRailLabelType.all,
                  destinations: _destinations
                      .map((d) => NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)))
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(_destinations[_selectedIndex].label)),
          body: page,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            destinations: _destinations
                .map((d) => NavigationDestination(icon: Icon(d.icon), label: d.label))
                .toList(),
          ),
        );
      },
    );
  }
}
