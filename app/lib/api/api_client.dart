import 'dart:convert';

import 'package:http/http.dart' as http;

import '../connection/connection_info.dart';
import 'api_exception.dart';
import 'models.dart';

/// Thin typed wrapper over the backend's REST API (see backend/app/routers/*.py). Every
/// method throws [ApiException] on a non-2xx response, with the message extracted from
/// FastAPI's error body shape (see api_exception.dart).
class ApiClient {
  final ConnectionInfo connection;
  final http.Client _http;

  ApiClient(this.connection, {http.Client? httpClient}) : _http = httpClient ?? http.Client();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (connection.token != null && connection.token!.isNotEmpty)
      'Authorization': 'Bearer ${connection.token}',
  };

  Uri _uri(String path) => Uri.parse('${connection.baseUrl}$path');

  Future<dynamic> _decodeOrThrow(http.Response response) async {
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw ApiException.fromResponseBody(response.statusCode, body);
  }

  Future<dynamic> _get(String path) async =>
      _decodeOrThrow(await _http.get(_uri(path), headers: _headers));

  Future<dynamic> _post(String path, [Object? body]) async =>
      _decodeOrThrow(await _http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> _patch(String path, Object body) async =>
      _decodeOrThrow(await _http.patch(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<void> _delete(String path) async {
    await _decodeOrThrow(await _http.delete(_uri(path), headers: _headers));
  }

  Future<bool> checkHealth() async {
    try {
      final response = await _http.get(_uri('/health')).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- Buildings ---

  Future<List<Building>> listBuildings() async =>
      ((await _get('/buildings')) as List).map((j) => Building.fromJson(j)).toList();

  Future<Building> createBuilding({
    required String name,
    required int openingMinutes,
    required int closingMinutes,
  }) async => Building.fromJson(
    await _post('/buildings', {
      'name': name,
      'opening_minutes': openingMinutes,
      'closing_minutes': closingMinutes,
    }),
  );

  Future<Building> updateBuilding(
    int id, {
    String? name,
    int? openingMinutes,
    int? closingMinutes,
  }) async => Building.fromJson(
    await _patch('/buildings/$id', {
      'name': ?name,
      'opening_minutes': ?openingMinutes,
      'closing_minutes': ?closingMinutes,
    }),
  );

  Future<void> deleteBuilding(int id) => _delete('/buildings/$id');

  // --- Rooms ---

  Future<List<Room>> listRooms() async =>
      ((await _get('/rooms')) as List).map((j) => Room.fromJson(j)).toList();

  Future<Room> createRoom({
    required String name,
    required int buildingId,
    List<int> tagIds = const [],
  }) async => Room.fromJson(
    await _post('/rooms', {'name': name, 'building_id': buildingId, 'tag_ids': tagIds}),
  );

  Future<Room> updateRoom(int id, {String? name, int? buildingId, List<int>? tagIds}) async =>
      Room.fromJson(
        await _patch('/rooms/$id', {
          'name': ?name,
          'building_id': ?buildingId,
          'tag_ids': ?tagIds,
        }),
      );

  Future<void> deleteRoom(int id) => _delete('/rooms/$id');

  // --- Tags ---

  Future<List<Tag>> listTags() async =>
      ((await _get('/tags')) as List).map((j) => Tag.fromJson(j)).toList();

  Future<Tag> createTag(String name) async => Tag.fromJson(await _post('/tags', {'name': name}));

  Future<Tag> updateTag(int id, String name) async =>
      Tag.fromJson(await _patch('/tags/$id', {'name': name}));

  Future<void> deleteTag(int id) => _delete('/tags/$id');

  // --- Roles ---

  Future<List<Role>> listRoles() async =>
      ((await _get('/roles')) as List).map((j) => Role.fromJson(j)).toList();

  Future<Role> createRole(String name) async =>
      Role.fromJson(await _post('/roles', {'name': name}));

  Future<Role> updateRole(int id, String name) async =>
      Role.fromJson(await _patch('/roles/$id', {'name': name}));

  Future<void> deleteRole(int id) => _delete('/roles/$id');

  // --- Staff ---

  Future<List<Staff>> listStaff() async =>
      ((await _get('/staff')) as List).map((j) => Staff.fromJson(j)).toList();

  Future<Staff> createStaff({
    required String name,
    bool active = true,
    List<int> roleIds = const [],
    List<PreferredDay> preferredDays = const [],
  }) async => Staff.fromJson(
    await _post('/staff', {
      'name': name,
      'active': active,
      'role_ids': roleIds,
      'preferred_days': preferredDays.map((d) => d.toJson()).toList(),
    }),
  );

  Future<Staff> updateStaff(
    int id, {
    String? name,
    bool? active,
    List<int>? roleIds,
    List<PreferredDay>? preferredDays,
  }) async => Staff.fromJson(
    await _patch('/staff/$id', {
      'name': ?name,
      'active': ?active,
      'role_ids': ?roleIds,
      if (preferredDays != null) 'preferred_days': preferredDays.map((d) => d.toJson()).toList(),
    }),
  );

  Future<void> deleteStaff(int id) => _delete('/staff/$id');

  Future<Unavailability> addUnavailability(
    int staffId, {
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async => Unavailability.fromJson(
    await _post('/staff/$staffId/unavailabilities', {
      'start_date': dateToJson(startDate),
      'end_date': dateToJson(endDate),
      'reason': ?reason,
    }),
  );

  Future<void> removeUnavailability(int staffId, int unavailabilityId) =>
      _delete('/staff/$staffId/unavailabilities/$unavailabilityId');

  // --- Rules ---

  Future<List<Rule>> listRules() async =>
      ((await _get('/rules')) as List).map((j) => Rule.fromJson(j)).toList();

  Future<Rule> createRule({
    required String name,
    required RuleType ruleType,
    required int roleId,
    int? buildingId,
    int? tagId,
    int? minimumCount,
  }) async => Rule.fromJson(
    await _post('/rules', {
      'name': name,
      'rule_type': ruleType.value,
      'role_id': roleId,
      'building_id': buildingId,
      'tag_id': tagId,
      'minimum_count': minimumCount,
    }),
  );

  Future<void> deleteRule(int id) => _delete('/rules/$id');

  // --- Settings ---

  Future<AppSettings> getSettings() async => AppSettings.fromJson(await _get('/settings'));

  Future<AppSettings> updateSettings({
    int? shiftLengthMinutes,
    int? travelTimeMinutes,
    int? maxDailyMinutes,
  }) async => AppSettings.fromJson(
    await _patch('/settings', {
      'shift_length_minutes': ?shiftLengthMinutes,
      'travel_time_minutes': ?travelTimeMinutes,
      'max_daily_minutes': ?maxDailyMinutes,
    }),
  );

  // --- Rosters ---

  Future<List<Roster>> listRosters() async =>
      ((await _get('/rosters')) as List).map((j) => Roster.fromJson(j)).toList();

  Future<Roster> generateRoster({required DateTime startDate, int numDays = 14}) async =>
      Roster.fromJson(
        await _post('/rosters', {'start_date': dateToJson(startDate), 'num_days': numDays}),
      );

  Future<RosterDetail> getRoster(int id) async =>
      RosterDetail.fromJson(await _get('/rosters/$id'));

  Future<Roster> regenerateRoster(int id) async =>
      Roster.fromJson(await _post('/rosters/$id/regenerate'));

  Future<Shift> updateShift(int rosterId, int shiftId, {required int staffId}) async =>
      Shift.fromJson(await _patch('/rosters/$rosterId/shifts/$shiftId', {'staff_id': staffId}));
}
