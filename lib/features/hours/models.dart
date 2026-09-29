class Workspace {
  const Workspace(this.id, this.name);
  final int id;
  final String name;
}

String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime weekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);
String durationLabel(int minutes) => '${minutes ~/ 60}h ${minutes % 60}m';

class HoursEntry {
  const HoursEntry({
    required this.date,
    required this.start,
    required this.end,
    required this.breakMinutes,
    required this.paidBreak,
    required this.notes,
    required this.netMinutes,
  });
  final DateTime date;
  final String start, end, notes;
  final int breakMinutes, netMinutes;
  final bool paidBreak;
}

class HoursDraft {
  HoursDraft({
    required this.date,
    required this.start,
    required this.end,
    required this.breakMinutes,
    required this.paidBreak,
    required this.notes,
  });
  final DateTime date;
  final String start, end, notes;
  final int breakMinutes;
  final bool paidBreak;
  static int? clock(String value) {
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) return null;
    final parts = value.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  Map<String, String> validate() {
    final errors = <String, String>{};
    final from = clock(start), to = clock(end);
    if (from == null) errors['start'] = 'Use 24-hour time, for example 09:00.';
    if (to == null) errors['end'] = 'Use 24-hour time, for example 17:00.';
    if (from != null && to != null) {
      if (to <= from) errors['end'] = 'End must follow start on the same day.';
      if (breakMinutes >= to - from) {
        errors['break'] = 'Break must be shorter than the shift.';
      }
    }
    if (breakMinutes < 0 || breakMinutes > 1439) {
      errors['break'] = 'Enter break minutes from 0 to 1439.';
    }
    if (notes.length > 5000) errors['notes'] = 'Use 5000 characters or fewer.';
    return errors;
  }
}
