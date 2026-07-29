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
  final Widget Function(ApiClient api, VoidCallback onDisconnect) buildPage;

  const _Destination({
    required this.label,
    required this.icon,
    required this.buildPage,
  });
}

/// Adaptive navigation shell wrapping every resource screen: a NavigationRail on
/// desktop/tablet-width windows, a bottom NavigationBar on phone widths — same set of
/// destinations either way, so the CRUD screens underneath don't need to know which shell
/// they're hosted in.
class AppShell extends StatefulWidget {
  final ApiClient api;

  /// Clears the stored connection and returns to the pairing screen — the only way back
  /// there once paired (see SettingsPage's "Disconnect" action), needed if the pairing
  /// token changes or the admin wants to point this device at a different backend.
  final VoidCallback onDisconnect;

  const AppShell({super.key, required this.api, required this.onDisconnect});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static final _destinations = <_Destination>[
    _Destination(
      label: 'Rosters',
      icon: Icons.calendar_month,
      buildPage: (api, _) => RostersPage(api: api),
    ),
    _Destination(
      label: 'Staff',
      icon: Icons.people,
      buildPage: (api, _) => StaffPage(api: api),
    ),
    _Destination(
      label: 'Buildings',
      icon: Icons.apartment,
      buildPage: (api, _) => BuildingsPage(api: api),
    ),
    _Destination(
      label: 'Rooms',
      icon: Icons.meeting_room,
      buildPage: (api, _) => RoomsPage(api: api),
    ),
    _Destination(
      label: 'Tags',
      icon: Icons.label,
      buildPage: (api, _) => TagsPage(api: api),
    ),
    _Destination(
      label: 'Roles',
      icon: Icons.badge,
      buildPage: (api, _) => RolesPage(api: api),
    ),
    _Destination(
      label: 'Rules',
      icon: Icons.rule,
      buildPage: (api, _) => RulesPage(api: api),
    ),
    _Destination(
      label: 'Settings',
      icon: Icons.settings,
      buildPage: (api, onDisconnect) =>
          SettingsPage(api: api, onDisconnect: onDisconnect),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final page = _destinations[_selectedIndex].buildPage(
      widget.api,
      widget.onDisconnect,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  labelType: NavigationRailLabelType.all,
                  destinations: _destinations
                      .map(
                        (d) => NavigationRailDestination(
                          icon: Icon(d.icon),
                          label: Text(d.label),
                        ),
                      )
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
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            destinations: _destinations
                .map(
                  (d) =>
                      NavigationDestination(icon: Icon(d.icon), label: d.label),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
