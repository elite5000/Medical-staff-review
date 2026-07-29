import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/connection/connection_info.dart';
import 'package:app/features/rosters/roster_view_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient _api(MockClient client) =>
    ApiClient(ConnectionInfo(host: 'test', port: 1234), httpClient: client);

const _buildings = [
  {
    'id': 1,
    'name': 'Hospital',
    'opening_minutes': 480,
    'closing_minutes': 1080,
  },
];
const _tags = [
  {'id': 1, 'name': 'Surgery'},
];
const _rooms = [
  {'id': 1, 'name': 'Room B', 'building_id': 1, 'tags': <Object>[]},
  {'id': 2, 'name': 'Room A', 'building_id': 1, 'tags': <Object>[]},
];
const _settings = {
  'shift_length_minutes': 60,
  'travel_time_minutes': 15,
  'max_daily_minutes': 480,
};
const _staff = [
  {
    'id': 1,
    'name': 'Dr. Alice',
    'active': true,
    'roles': <Object>[],
    'preferred_days': <Object>[],
    'unavailabilities': <Object>[],
  },
  {
    'id': 2,
    'name': 'Dr. Bob',
    'active': true,
    'roles': <Object>[],
    'preferred_days': <Object>[],
    'unavailabilities': <Object>[],
  },
];

Map<String, dynamic> _rosterSummary({
  required int id,
  String generatedAt = '2026-01-01T00:00:00',
}) => {
  'id': id,
  'start_date': '2026-01-05',
  'end_date': '2026-01-06',
  'generated_at': generatedAt,
  'generated_from_roster_id': null,
  'has_violations': false,
};

MockClient _client({
  required Map<String, dynamic> detail,
  required List<Map<String, dynamic>> rosterList,
  void Function(Uri url, String body)? onPatch,
}) => MockClient((request) async {
  if (request.method == 'GET' && request.url.path == '/rosters/1') {
    return http.Response(jsonEncode(detail), 200);
  }
  if (request.method == 'GET' && request.url.path == '/rosters') {
    return http.Response(jsonEncode(rosterList), 200);
  }
  if (request.method == 'GET' && request.url.path == '/rooms') {
    return http.Response(jsonEncode(_rooms), 200);
  }
  if (request.method == 'GET' && request.url.path == '/staff') {
    return http.Response(jsonEncode(_staff), 200);
  }
  if (request.method == 'GET' && request.url.path == '/buildings') {
    return http.Response(jsonEncode(_buildings), 200);
  }
  if (request.method == 'GET' && request.url.path == '/tags') {
    return http.Response(jsonEncode(_tags), 200);
  }
  if (request.method == 'GET' && request.url.path == '/settings') {
    return http.Response(jsonEncode(_settings), 200);
  }
  if (request.method == 'PATCH' && request.url.path == '/rosters/1/shifts/1') {
    onPatch?.call(request.url, request.body);
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    return http.Response(
      jsonEncode({
        'id': 1,
        'room_id': 1,
        'staff_id': body['staff_id'],
        'date': '2026-01-05',
        'shift_index': 0,
        'pinned': false,
      }),
      200,
    );
  }
  return http.Response('not found', 404);
});

void main() {
  testWidgets('shows shifts grouped by date and sorted by room name', (
    tester,
  ) async {
    final detail = {
      ..._rosterSummary(id: 1),
      'shifts': [
        {
          'id': 1,
          'room_id': 1, // Room B
          'staff_id': 1,
          'date': '2026-01-05',
          'shift_index': 0,
          'pinned': true,
        },
        {
          'id': 2,
          'room_id': 2, // Room A
          'staff_id': 2,
          'date': '2026-01-05',
          'shift_index': 0,
          'pinned': false,
        },
      ],
      'violations': <Object>[],
    };

    final api = _api(
      _client(detail: detail, rosterList: [_rosterSummary(id: 1)]),
    );

    await tester.pumpWidget(
      MaterialApp(home: RosterViewPage(api: api, rosterId: 1)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        '2026-01-05 – 2026-01-06 '
        '(generated ${DateTime.parse('2026-01-01T00:00:00')})',
      ),
      findsOneWidget,
    );

    // Room A sorts before Room B despite arriving second in the shifts array.
    final roomATile = tester.getTopLeft(find.text('Room A · shift 0'));
    final roomBTile = tester.getTopLeft(find.text('Room B · shift 0'));
    expect(roomATile.dy, lessThan(roomBTile.dy));
    expect(find.text('Pinned: Yes'), findsOneWidget);
    expect(find.text('Pinned: No'), findsOneWidget);
  });

  testWidgets('shows violation labels for both violation types', (
    tester,
  ) async {
    final detail = {
      ..._rosterSummary(id: 1),
      'shifts': <Object>[],
      'violations': [
        {
          'id': 1,
          'violation_type': 'room_unfilled',
          'rule_id': null,
          'building_id': null,
          'tag_id': null,
          'room_id': 1,
          'date': '2026-01-05',
          'shift_index': 0,
          'detail': null,
        },
        {
          'id': 2,
          'violation_type': 'minimum_count_unmet',
          'rule_id': 1,
          'building_id': 1,
          'tag_id': null,
          'room_id': null,
          'date': '2026-01-05',
          'shift_index': 1,
          'detail': 'only 1 of 2 filled',
        },
      ],
    };

    final api = _api(
      _client(detail: detail, rosterList: [_rosterSummary(id: 1)]),
    );

    await tester.pumpWidget(
      MaterialApp(home: RosterViewPage(api: api, rosterId: 1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Violations'), findsOneWidget);
    expect(
      find.text('• Room B unfilled on 2026-01-05 (shift 0)'),
      findsOneWidget,
    );
    expect(
      find.text(
        '• Minimum-count rule unmet for Building: Hospital on 2026-01-05 '
        '(shift 1) — only 1 of 2 filled',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reassigns a shift on the latest generation via the dropdown', (
    tester,
  ) async {
    final detail = {
      ..._rosterSummary(id: 1),
      'shifts': [
        {
          'id': 1,
          'room_id': 1,
          'staff_id': 1,
          'date': '2026-01-05',
          'shift_index': 0,
          'pinned': false,
        },
      ],
      'violations': <Object>[],
    };
    Uri? patchedUrl;
    String? patchedBody;

    final api = _api(
      _client(
        detail: detail,
        // This generation is the only one for its date range, so it's the latest — editable.
        rosterList: [_rosterSummary(id: 1)],
        onPatch: (url, body) {
          patchedUrl = url;
          patchedBody = body;
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: RosterViewPage(api: api, rosterId: 1)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<int>), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dr. Bob').last);
    await tester.pumpAndSettle();

    expect(patchedUrl?.path, '/rosters/1/shifts/1');
    expect(jsonDecode(patchedBody!), {'staff_id': 2});
  });

  testWidgets('shows a read-only staff name when a newer generation exists', (
    tester,
  ) async {
    final detail = {
      ..._rosterSummary(id: 1),
      'shifts': [
        {
          'id': 1,
          'room_id': 1,
          'staff_id': 1,
          'date': '2026-01-05',
          'shift_index': 0,
          'pinned': false,
        },
      ],
      'violations': <Object>[],
    };

    final api = _api(
      _client(
        detail: detail,
        rosterList: [
          _rosterSummary(id: 1),
          // Same date range, generated later — this roster (id 1) is no longer the latest.
          _rosterSummary(id: 2, generatedAt: '2026-01-02T00:00:00'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: RosterViewPage(api: api, rosterId: 1)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButton<int>), findsNothing);
    expect(find.text('Dr. Alice'), findsOneWidget);
  });

  testWidgets('shows an error banner when reassignment fails', (tester) async {
    final detail = {
      ..._rosterSummary(id: 1),
      'shifts': [
        {
          'id': 1,
          'room_id': 1,
          'staff_id': 1,
          'date': '2026-01-05',
          'shift_index': 0,
          'pinned': false,
        },
      ],
      'violations': <Object>[],
    };

    final api = _api(
      MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/rosters/1') {
          return http.Response(jsonEncode(detail), 200);
        }
        if (request.method == 'GET' && request.url.path == '/rosters') {
          return http.Response(jsonEncode([_rosterSummary(id: 1)]), 200);
        }
        if (request.method == 'GET' && request.url.path == '/rooms') {
          return http.Response(jsonEncode(_rooms), 200);
        }
        if (request.method == 'GET' && request.url.path == '/staff') {
          return http.Response(jsonEncode(_staff), 200);
        }
        if (request.method == 'GET' && request.url.path == '/buildings') {
          return http.Response(jsonEncode(_buildings), 200);
        }
        if (request.method == 'GET' && request.url.path == '/tags') {
          return http.Response(jsonEncode(_tags), 200);
        }
        if (request.method == 'GET' && request.url.path == '/settings') {
          return http.Response(jsonEncode(_settings), 200);
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/rosters/1/shifts/1') {
          return http.Response(
            jsonEncode({'detail': 'Staff member is unavailable that day'}),
            409,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: RosterViewPage(api: api, rosterId: 1)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dr. Bob').last);
    await tester.pumpAndSettle();

    expect(find.text('Staff member is unavailable that day'), findsOneWidget);
  });
}
