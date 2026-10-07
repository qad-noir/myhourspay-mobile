import '../features/hours/chart_allocation.dart';

import 'package:flutter/material.dart';

import 'widgets.dart';
import '../features/hours/models.dart';

const shortDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
String shortDate(DateTime d) => '${d.day} ${months[d.month - 1]}';
String weekLabel(DateTime d) =>
    '${shortDate(d)} – ${shortDate(d.add(Duration(days: 6)))}';
String capitalized(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class EntryRow extends StatelessWidget {
  const EntryRow({super.key, required this.entry, this.onTap});
  final HoursEntry entry;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 58,
            padding: EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: mhpColor(context, Color(0xfff2f0ed)),
              border: Border.all(
                color: mhpColor(context, brandBorder).withValues(alpha: .5),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  shortDays[entry.date.weekday - 1].toUpperCase(),
                  style: TextStyle(fontSize: 12),
                ),
                Text(shortDate(entry.date), style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.start} – ${entry.end}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (entry.notes.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    entry.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: mhpColor(context, brandMuted),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(
            durationLabel(entry.netMinutes),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          if (onTap != null) ...[
            SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 20),
          ],
        ],
      ),
    ),
  );
}

class WeekChart extends StatelessWidget {
  const WeekChart({
    super.key,
    required this.week,
    required this.entries,
    this.onDayTap,
    this.dailyContract,
  });
  final DateTime week;
  final List<HoursEntry> entries;
  final ValueChanged<DateTime>? onDayTap;
  final int? dailyContract;
  @override
  Widget build(BuildContext context) {
    final days = allocateDailyWeek(
      week: week,
      entries: entries,
      dailyContract: dailyContract,
    );
    final maximum = days.fold<int>(
      480,
      (value, day) => day.total > value ? day.total : value,
    );
    final available = days.every((day) => day.overtime != null);
    String description(ChartDay day) => available
        ? '${durationLabel(day.regular)} regular, ${durationLabel(day.overtime!)} daily overtime'
        : '${durationLabel(day.total)} logged, daily overtime not configured';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: Semantics(
                  button: onDayTap != null,
                  label:
                      '${shortDays[i]}: ${description(days[i])}. ${entries.any((entry) => dateKey(entry.date) == dateKey(days[i].date)) ? 'Edit hours' : 'Add hours'}',
                  child: Tooltip(
                    message: description(days[i]),
                    child: InkWell(
                      onTap: onDayTap == null
                          ? null
                          : () => onDayTap!(days[i].date),
                      child: Padding(
                        padding: EdgeInsets.only(right: i == 6 ? 0 : 9),
                        child: Column(
                          children: [
                            Text(
                              days[i].total == 0
                                  ? '–'
                                  : '${(days[i].total / 60).toStringAsFixed(days[i].total % 60 == 0 ? 0 : 1)}h',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 84,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: days[i].total == 0
                                    ? const SizedBox.shrink()
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: SizedBox(
                                          height: 84 * days[i].total / maximum,
                                          width: double.infinity,
                                          child: Column(
                                            children: [
                                              if (available &&
                                                  days[i].overtime! > 0)
                                                Expanded(
                                                  flex: days[i].overtime!,
                                                  child: Container(
                                                    color: const Color(
                                                      0xff168456,
                                                    ),
                                                  ),
                                                ),
                                              if (!available ||
                                                  days[i].regular > 0)
                                                Expanded(
                                                  flex: available
                                                      ? days[i].regular
                                                      : days[i].total,
                                                  child: Container(
                                                    color: const Color(
                                                      0xffff6b35,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              shortDays[i],
                              style: TextStyle(
                                color: mhpColor(context, brandMuted),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _legend('Regular hours', const Color(0xffff6b35)),
            _legend('Daily overtime', const Color(0xff168456)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          !available
              ? 'Daily overtime not configured'
              : 'Daily overtime shows hours above the daily contract.',
          style: TextStyle(fontSize: 12, color: mhpColor(context, brandMuted)),
        ),
      ],
    );
  }

  Widget _legend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
