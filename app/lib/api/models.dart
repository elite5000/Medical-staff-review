/// Data models mirroring backend/app/schemas/*.py. Hand-written rather than generated —
/// the API surface is small and stable (8 resource groups, all owned by this repo), so a
/// full OpenAPI codegen toolchain (which would need a JDK for openapi-generator-cli) wasn't
/// worth the added dependency.
library;

String dateToJson(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class Building {
  final int id;
  final String name;
  final int openingMinutes;
  final int closingMinutes;

  Building({
    required this.id,
    required this.name,
    required this.openingMinutes,
    required this.closingMinutes,
  });

  factory Building.fromJson(Map<String, dynamic> json) => Building(
    id: json['id'] as int,
    name: json['name'] as String,
    openingMinutes: json['opening_minutes'] as int,
    closingMinutes: json['closing_minutes'] as int,
  );
}

class Tag {
  final int id;
  final String name;

  Tag({required this.id, required this.name});

  factory Tag.fromJson(Map<String, dynamic> json) =>
      Tag(id: json['id'] as int, name: json['name'] as String);
}

class Room {
  final int id;
  final String name;
  final int buildingId;
  final List<Tag> tags;

  Room({
    required this.id,
    required this.name,
    required this.buildingId,
    required this.tags,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: json['id'] as int,
    name: json['name'] as String,
    buildingId: json['building_id'] as int,
    tags: (json['tags'] as List)
        .map((t) => Tag.fromJson(t as Map<String, dynamic>))
        .toList(),
  );
}

class Role {
  final int id;
  final String name;

  Role({required this.id, required this.name});

  factory Role.fromJson(Map<String, dynamic> json) =>
      Role(id: json['id'] as int, name: json['name'] as String);
}

/// week: 0 = week 1, 1 = week 2 of the fortnight. dayOfWeek: 0 = Monday ... 6 = Sunday.
class PreferredDay {
  final int week;
  final int dayOfWeek;

  PreferredDay({required this.week, required this.dayOfWeek});

  factory PreferredDay.fromJson(Map<String, dynamic> json) => PreferredDay(
    week: json['week'] as int,
    dayOfWeek: json['day_of_week'] as int,
  );

  Map<String, dynamic> toJson() => {'week': week, 'day_of_week': dayOfWeek};
}

class Unavailability {
  final int id;
  final int staffId;
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;

  Unavailability({
    required this.id,
    required this.staffId,
    required this.startDate,
    required this.endDate,
    this.reason,
  });

  factory Unavailability.fromJson(Map<String, dynamic> json) => Unavailability(
    id: json['id'] as int,
    staffId: json['staff_id'] as int,
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    reason: json['reason'] as String?,
  );
}

class Staff {
  final int id;
  final String name;
  final bool active;
  final List<Role> roles;
  final List<PreferredDay> preferredDays;
  final List<Unavailability> unavailabilities;

  Staff({
    required this.id,
    required this.name,
    required this.active,
    required this.roles,
    required this.preferredDays,
    required this.unavailabilities,
  });

  factory Staff.fromJson(Map<String, dynamic> json) => Staff(
    id: json['id'] as int,
    name: json['name'] as String,
    active: json['active'] as bool,
    roles: (json['roles'] as List)
        .map((r) => Role.fromJson(r as Map<String, dynamic>))
        .toList(),
    preferredDays: (json['preferred_days'] as List)
        .map((d) => PreferredDay.fromJson(d as Map<String, dynamic>))
        .toList(),
    unavailabilities: (json['unavailabilities'] as List)
        .map((u) => Unavailability.fromJson(u as Map<String, dynamic>))
        .toList(),
  );
}

/// Result of a `POST .../bulk` create (mirrors backend/app/schemas/bulk.py's
/// BulkCreateResult). [skipped] only ever has entries for Tags and Roles — the entities
/// whose name column is UNIQUE, where a pasted name that already exists is reported back
/// instead of failing the whole batch. It stays empty for Rooms and Staff.
class BulkAddResult<T> {
  final List<T> created;
  final List<String> skipped;

  BulkAddResult({required this.created, required this.skipped});

  factory BulkAddResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) => BulkAddResult(
    created: (json['created'] as List)
        .map((item) => itemFromJson(item as Map<String, dynamic>))
        .toList(),
    skipped: (json['skipped'] as List).cast<String>(),
  );
}

enum RuleType {
  minimumCount('minimum_count'),
  eligibilityRestriction('eligibility_restriction');

  final String value;
  const RuleType(this.value);

  static RuleType fromJson(String value) =>
      RuleType.values.firstWhere((t) => t.value == value);
}

class Rule {
  final int id;
  final String name;
  final RuleType ruleType;
  final int roleId;
  final int? buildingId;
  final int? tagId;
  final int? minimumCount;

  Rule({
    required this.id,
    required this.name,
    required this.ruleType,
    required this.roleId,
    this.buildingId,
    this.tagId,
    this.minimumCount,
  });

  factory Rule.fromJson(Map<String, dynamic> json) => Rule(
    id: json['id'] as int,
    name: json['name'] as String,
    ruleType: RuleType.fromJson(json['rule_type'] as String),
    roleId: json['role_id'] as int,
    buildingId: json['building_id'] as int?,
    tagId: json['tag_id'] as int?,
    minimumCount: json['minimum_count'] as int?,
  );
}

class AppSettings {
  final int shiftLengthMinutes;
  final int travelTimeMinutes;
  final int maxDailyMinutes;

  AppSettings({
    required this.shiftLengthMinutes,
    required this.travelTimeMinutes,
    required this.maxDailyMinutes,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    shiftLengthMinutes: json['shift_length_minutes'] as int,
    travelTimeMinutes: json['travel_time_minutes'] as int,
    maxDailyMinutes: json['max_daily_minutes'] as int,
  );
}

enum ViolationType {
  minimumCountUnmet('minimum_count_unmet'),
  roomUnfilled('room_unfilled');

  final String value;
  const ViolationType(this.value);

  static ViolationType fromJson(String value) =>
      ViolationType.values.firstWhere((t) => t.value == value);
}

class Shift {
  final int id;
  final int roomId;
  final int staffId;
  final DateTime date;
  final int shiftIndex;
  final bool pinned;

  Shift({
    required this.id,
    required this.roomId,
    required this.staffId,
    required this.date,
    required this.shiftIndex,
    required this.pinned,
  });

  factory Shift.fromJson(Map<String, dynamic> json) => Shift(
    id: json['id'] as int,
    roomId: json['room_id'] as int,
    staffId: json['staff_id'] as int,
    date: DateTime.parse(json['date'] as String),
    shiftIndex: json['shift_index'] as int,
    pinned: json['pinned'] as bool,
  );
}

class RosterViolation {
  final int id;
  final ViolationType violationType;
  final int? ruleId;
  final int? buildingId;
  final int? tagId;
  final int? roomId;
  final DateTime date;
  final int shiftIndex;
  final String? detail;

  RosterViolation({
    required this.id,
    required this.violationType,
    this.ruleId,
    this.buildingId,
    this.tagId,
    this.roomId,
    required this.date,
    required this.shiftIndex,
    this.detail,
  });

  factory RosterViolation.fromJson(Map<String, dynamic> json) =>
      RosterViolation(
        id: json['id'] as int,
        violationType: ViolationType.fromJson(json['violation_type'] as String),
        ruleId: json['rule_id'] as int?,
        buildingId: json['building_id'] as int?,
        tagId: json['tag_id'] as int?,
        roomId: json['room_id'] as int?,
        date: DateTime.parse(json['date'] as String),
        shiftIndex: json['shift_index'] as int,
        detail: json['detail'] as String?,
      );
}

class Roster {
  final int id;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime generatedAt;
  final int? generatedFromRosterId;
  final bool hasViolations;

  Roster({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.generatedAt,
    this.generatedFromRosterId,
    required this.hasViolations,
  });

  factory Roster.fromJson(Map<String, dynamic> json) => Roster(
    id: json['id'] as int,
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    generatedAt: DateTime.parse(json['generated_at'] as String),
    generatedFromRosterId: json['generated_from_roster_id'] as int?,
    hasViolations: json['has_violations'] as bool,
  );
}

class RosterDetail extends Roster {
  final List<Shift> shifts;
  final List<RosterViolation> violations;

  RosterDetail({
    required super.id,
    required super.startDate,
    required super.endDate,
    required super.generatedAt,
    super.generatedFromRosterId,
    required super.hasViolations,
    required this.shifts,
    required this.violations,
  });

  factory RosterDetail.fromJson(Map<String, dynamic> json) => RosterDetail(
    id: json['id'] as int,
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    generatedAt: DateTime.parse(json['generated_at'] as String),
    generatedFromRosterId: json['generated_from_roster_id'] as int?,
    hasViolations: json['has_violations'] as bool,
    shifts: (json['shifts'] as List)
        .map((s) => Shift.fromJson(s as Map<String, dynamic>))
        .toList(),
    violations: (json['violations'] as List)
        .map((v) => RosterViolation.fromJson(v as Map<String, dynamic>))
        .toList(),
  );
}
