import 'models.dart';

class ChartDay {
  const ChartDay(this.date, this.regular, this.overtime);
  final DateTime date;
  final int regular;
  // Null means the configured calculation is unavailable, never zero overtime.
  final int? overtime;
  int get total => regular + (overtime ?? 0);
}

// Display-only daily split, independent of the workspace summary selection. Entry data,
// compensation and opaque versions are never changed by this calculation.
List<ChartDay> allocateDailyWeek({
  required DateTime week,
  required List<HoursEntry> entries,
  int? dailyContract,
}) {
  return List.generate(7, (index) {
    final date = DateTime(week.year, week.month, week.day + index);
    final records = entries
        .where((entry) => dateKey(entry.date) == dateKey(date))
        .toList();
    final total = records.fold<int>(0, (sum, entry) => sum + entry.netMinutes);
    if (dailyContract == null) return ChartDay(date, total, null);
    final overtime =
        records.every((entry) => entry.dailyOvertimeMinutes != null)
        ? records.fold<int>(
            0,
            (sum, entry) => sum + entry.dailyOvertimeMinutes!,
          )
        : (total - dailyContract).clamp(0, total);
    return ChartDay(
      date,
      total - overtime.clamp(0, total),
      overtime.clamp(0, total),
    );
  });
}
