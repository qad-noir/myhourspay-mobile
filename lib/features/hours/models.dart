import 'package:timezone/timezone.dart' as tz;

import '../../core/api_client.dart';
import '../../core/json_fields.dart';

String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime weekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);
String durationLabel(int minutes) => '${minutes ~/ 60}h ${minutes.abs() % 60}m';
DateTime workspaceToday(String zone) {
  final now = tz.TZDateTime.now(tz.getLocation(zone));
  return DateTime(now.year, now.month, now.day);
}

class Workspace {
  Workspace.fromJson(Json json)
    : id = jsonId(json['id']),
      name = json['name'] as String,
      role = json['role'] as String,
      currency = json['currency'] as String?,
      writable = json['writable'] as bool,
      timezone = json['timezone'] as String,
      defaultBreak = json['default_break_minutes'] as int,
      paidBreak = json['default_break_type'] == 'paid',
      targetMinutes = json['weekly_target_minutes'] as int,
      contractedDailyMinutes = json['contracted_daily_minutes'] as int?,
      overtimeBasis = json['overtime_basis'] as String? ?? 'weekly',
      settingsVersion = json['settings_version'] as String?,
      canManageSettings = json['can_manage_settings'] == true,
      settingsSupported =
          json.containsKey('can_manage_settings') &&
          json['settings_version'] is String &&
          RegExp(r'^[a-f0-9]{64}$')
              .hasMatch(json['settings_version'] as String) &&
          json.containsKey('overtime_basis'),
      projectsEnabled = json['features']['clients_projects'] as bool,
      timesheetsEnabled = json['features']['timesheet_approvals'] as bool;
  final int id, defaultBreak, targetMinutes;
  final int? contractedDailyMinutes;
  final String overtimeBasis;
  final String? settingsVersion;
  final bool canManageSettings, settingsSupported;
  final String name, role, timezone;
  final String? currency;
  final bool writable, paidBreak, projectsEnabled, timesheetsEnabled;
  bool get canReview =>
      timesheetsEnabled && ['owner', 'administrator', 'manager'].contains(role);
}

class Project {
  Project.fromJson(Json json)
    : id = jsonId(json['id']),
      name = json['name'] as String;
  final int id;
  final String name;
}

class HoursEntry {
  HoursEntry.fromJson(Json json)
    : id = jsonId(json['id']),
      workspaceId = jsonId(json['workspace_id']),
      date = DateTime.parse(json['work_date'] as String),
      start = json['start_time'] as String,
      end = json['end_time'] as String,
      breakMinutes = json['break_minutes'] as int,
      paidBreak = json['break_type'] == 'paid',
      notes = json['notes'] as String? ?? '',
      netMinutes = json['net_minutes'] as int,
      dailyOvertimeMinutes = json['daily_overtime_minutes'] as int?,
      version = json['version'] as String,
      projectId = nullableJsonId(json['project_id']),
      billable = json['billable'] as bool;
  final int id, workspaceId, breakMinutes, netMinutes;
  final DateTime date;
  final String start, end, notes, version;
  final bool paidBreak, billable;
  final int? projectId, dailyOvertimeMinutes;
}

class HoursPage {
  HoursPage.fromJson(Json json)
    : entries = (json['data'] as List)
          .map((e) => HoursEntry.fromJson(e as Json))
          .toList(),
      totalMinutes = json['summary']['total_minutes'] as int,
      overtimeMinutes = json['summary']['overtime_minutes'] as int,
      overtime = OvertimeTotals.fromJson(json['summary'] as Json),
      lastPage = json['meta']['last_page'] as int,
      weeks = (json['summary']['weeks'] as List)
          .map((e) => HoursWeek.fromJson(e as Json))
          .toList();
  final List<HoursEntry> entries;
  final int totalMinutes, overtimeMinutes, lastPage;
  final List<HoursWeek> weeks;
  final OvertimeTotals overtime;
}

class HoursWeek {
  HoursWeek({
    required this.start,
    required this.minutes,
    required this.targetMinutes,
    this.dailyOvertimeMinutes,
    this.weeklyOvertimeMinutes,
    this.overtimeMinutes,
    this.serverVariance,
    this.partial = false,
  });
  HoursWeek.fromJson(Json json)
    : start = DateTime.parse(json['start'] as String),
      minutes = json['minutes'] as int,
      targetMinutes = json['target_minutes'] as int?,
      dailyOvertimeMinutes = json['daily_overtime_minutes'] as int?,
      weeklyOvertimeMinutes = json['weekly_overtime_minutes'] as int?,
      overtimeMinutes = json['overtime_minutes'] as int?,
      partial = json['partial'] == true,
      serverVariance = json['variance_minutes'] as int?;
  final bool partial;
  final DateTime start;
  final int minutes;
  final int? targetMinutes;
  final int? dailyOvertimeMinutes,
      weeklyOvertimeMinutes,
      overtimeMinutes,
      serverVariance;
  int? get variance =>
      serverVariance ??
      (targetMinutes == null ? null : minutes - targetMinutes!);
}

class OvertimeTotals {
  OvertimeTotals.fromJson(Json json)
    : basis = json['overtime_basis'] as String? ?? 'weekly',
      dailyContract = json['contracted_daily_minutes'] as int?,
      dailyMinutes = json['daily_overtime_minutes'] as int?,
      weeklyMinutes =
          json['weekly_overtime_minutes'] as int? ??
          (json['overtime_basis'] == 'daily'
              ? null
              : json['overtime_minutes'] as int?),
      selectedMinutes = json['overtime_minutes'] as int?;
  final String basis;
  final int? dailyContract, dailyMinutes, weeklyMinutes, selectedMinutes;
  String get label => basis == 'daily' ? 'Daily overtime' : 'Weekly overtime';
}

class HoursDraft {
  HoursDraft({
    required this.date,
    required this.start,
    required this.end,
    required this.breakMinutes,
    required this.paidBreak,
    required this.notes,
    this.projectId,
    this.billable = false,
  });
  final DateTime date;
  final String start, end, notes;
  final int breakMinutes;
  final bool paidBreak, billable;
  final int? projectId;
  Json toJson({String? version}) => {
    'work_date': dateKey(date),
    'start_time': start,
    'end_time': end,
    'break_minutes': breakMinutes,
    'break_type': paidBreak ? 'paid' : 'unpaid',
    'notes': notes.isEmpty ? null : notes,
    'project_id': projectId,
    'billable': billable,
    'version': ?version,
  };
  static int? clock(String value) {
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) return null;
    final parts = value.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  Map<String, String> validate() {
    final errors = <String, String>{};
    final from = clock(start), to = clock(end);
    if (from == null) {
      errors['start_time'] = 'Use 24-hour time, for example 09:00.';
    }
    if (to == null) errors['end_time'] = 'Use 24-hour time, for example 17:00.';
    if (from != null && to != null) {
      if (to <= from) {
        errors['end_time'] = 'End must follow start on the same day.';
      }
      if (breakMinutes >= to - from) {
        errors['break_minutes'] = 'Break must be shorter than the shift.';
      }
    }
    if (breakMinutes < 0 || breakMinutes > 1439) {
      errors['break_minutes'] = 'Enter 0 to 1439 minutes.';
    }
    if (notes.length > 500) errors['notes'] = 'Use 500 characters or fewer.';
    return errors;
  }
}
