import 'package:timezone/timezone.dart' as tz;

import '../../core/api_client.dart';

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
    : id = json['id'] as int,
      name = json['name'] as String,
      role = json['role'] as String,
      currency = json['currency'] as String?,
      writable = json['writable'] as bool,
      timezone = json['timezone'] as String,
      defaultBreak = json['default_break_minutes'] as int,
      paidBreak = json['default_break_type'] == 'paid',
      targetMinutes = json['weekly_target_minutes'] as int,
      projectsEnabled = json['features']['clients_projects'] as bool,
      timesheetsEnabled = json['features']['timesheet_approvals'] as bool;
  final int id, defaultBreak, targetMinutes;
  final String name, role, timezone;
  final String? currency;
  final bool writable, paidBreak, projectsEnabled, timesheetsEnabled;
  bool get canReview =>
      timesheetsEnabled && ['owner', 'administrator', 'manager'].contains(role);
}

class Project {
  Project.fromJson(Json json)
    : id = json['id'] as int,
      name = json['name'] as String;
  final int id;
  final String name;
}

class HoursEntry {
  HoursEntry.fromJson(Json json)
    : id = json['id'] as int,
      workspaceId = json['workspace_id'] as int,
      date = DateTime.parse(json['work_date'] as String),
      start = json['start_time'] as String,
      end = json['end_time'] as String,
      breakMinutes = json['break_minutes'] as int,
      paidBreak = json['break_type'] == 'paid',
      notes = json['notes'] as String? ?? '',
      netMinutes = json['net_minutes'] as int,
      version = json['version'] as String,
      projectId = json['project_id'] as int?,
      billable = json['billable'] as bool;
  final int id, workspaceId, breakMinutes, netMinutes;
  final DateTime date;
  final String start, end, notes, version;
  final bool paidBreak, billable;
  final int? projectId;
}

class HoursPage {
  HoursPage.fromJson(Json json)
    : entries = (json['data'] as List)
          .map((e) => HoursEntry.fromJson(e as Json))
          .toList(),
      totalMinutes = json['summary']['total_minutes'] as int,
      overtimeMinutes = json['summary']['overtime_minutes'] as int,
      lastPage = json['meta']['last_page'] as int;
  final List<HoursEntry> entries;
  final int totalMinutes, overtimeMinutes, lastPage;
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
