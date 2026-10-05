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
  });
  final DateTime week;
  final List<HoursEntry> entries;
  final ValueChanged<DateTime>? onDayTap;
  @override
  Widget build(BuildContext context) {
    final totals = List.generate(
      7,
      (i) => entries
          .where((e) => dateKey(e.date) == dateKey(week.add(Duration(days: i))))
          .fold<int>(0, (v, e) => v + e.netMinutes),
    );
    final max = totals.fold<int>(480, (v, e) => e > v ? e : v);
    return Semantics(
      label: List.generate(
        7,
        (i) => '${shortDays[i]}: ${durationLabel(totals[i])}',
      ).join(', '),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Semantics(
                button: onDayTap != null,
                label:
                    '${shortDays[i]}: ${durationLabel(totals[i])}. ${entries.any((e) => dateKey(e.date) == dateKey(week.add(Duration(days: i)))) ? 'Edit hours' : 'Add hours'}',
                child: InkWell(
                  onTap: onDayTap == null
                      ? null
                      : () => onDayTap!(week.add(Duration(days: i))),
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 6 ? 0 : 9),
                    child: Column(
                      children: [
                        Text(
                          totals[i] == 0
                              ? '–'
                              : '${(totals[i] / 60).toStringAsFixed(totals[i] % 60 == 0 ? 0 : 1)}h',
                          style: TextStyle(fontSize: 12),
                        ),
                        SizedBox(height: 6),
                        Container(
                          height: 72,
                          alignment: Alignment.bottomCenter,
                          decoration: BoxDecoration(
                            color: mhpColor(context, Color(0xffeeece9)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: FractionallySizedBox(
                            heightFactor: totals[i] / max,
                            widthFactor: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                color: brandOrange,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 7),
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
        ],
      ),
    );
  }
}
