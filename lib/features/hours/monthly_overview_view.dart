import 'package:flutter/material.dart';

import '../../shared/widgets.dart';
import '../../shared/overview_skeleton.dart';
import '../../core/api_client.dart';
import '../../shared/hours_widgets.dart';
import '../session/session_model.dart';
import 'models.dart';
import 'monthly_overview_model.dart';

const fullMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
String monthLabel(DateTime date) =>
    '${fullMonthNames[date.month - 1]} ${date.year}';
String compactHours(int minutes) =>
    minutes % 60 == 0 ? '${minutes ~/ 60}h' : durationLabel(minutes);
const overtimeInk = Color(0xff08664e);

class OverviewPeriodSwitch extends StatelessWidget {
  const OverviewPeriodSwitch({super.key, required this.model});
  final SessionModel model;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: mhpColor(context, brandBorder)),
      borderRadius: BorderRadius.circular(12),
    ),
    padding: EdgeInsets.all(3),
    child: Row(
      children: [
        for (final month in [false, true])
          Expanded(
            child: Semantics(
              selected: model.overviewMonthly == month,
              child: InkWell(
                onTap: () => model.setOverviewMonthly(month),
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  constraints: BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: model.overviewMonthly == month
                        ? mhpColor(context, brandPeach)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    month ? 'Month' : 'Week',
                    style: TextStyle(
                      fontWeight: model.overviewMonthly == month
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: mhpColor(context, brandInk),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class MonthlyOverviewView extends StatelessWidget {
  const MonthlyOverviewView({
    super.key,
    required this.model,
    required this.onAccount,
    required this.onEntry,
    this.onAddDate,
    this.initialLoading = true,
  });
  final SessionModel model;
  final bool initialLoading;
  final VoidCallback onAccount;
  final ValueChanged<HoursEntry> onEntry;
  final ValueChanged<DateTime>? onAddDate;
  MonthlyOverviewModel get state => model.monthly;
  Future<void> pickMonth(BuildContext context) async {
    final chosen = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPicker(initial: state.month),
    );
    if (chosen != null && context.mounted && model.workspace != null) {
      await state.selectMonth(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = model.workspace!;
    final month = state.month;
    final totals = state.totals;
    final entry = state.selectedEntry;
    final selected = state.selectedDate!;
    final calendarReady = totals != null;
    final awaitingCalendar = totals == null && state.calendarFailure == null;
    final awaitingWeeks =
        state.overtimeMinutes == null && state.weeksFailure == null;
    if (initialLoading && (awaitingCalendar || awaitingWeeks)) {
      return OverviewSkeleton(
        monthly: true,
        calendarRows: monthCells(month).length ~/ 7,
      );
    }
    final weekRows = state.snapshot?.fullWeeks != null
        ? state.weeks
        : [
            for (
              var day = weekStart(month);
              !day.isAfter(fullWeeksEnd(month));
              day = DateTime(day.year, day.month, day.day + 7)
            )
              HoursWeek(
                start: day,
                minutes: 0,
                targetMinutes: workspace.targetMinutes,
              ),
          ];
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: SingleChildScrollView(
          key: PageStorageKey('monthly-overview-scroll'),
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(22, 16, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: model.switchWorkspace,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/brand/brand-mark.png',
                              width: 36,
                              height: 36,
                            ),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                workspace.name,
                                maxLines: 2,
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Icon(Icons.expand_more, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Account and devices',
                    onPressed: onAccount,
                    icon: InitialAvatar(
                      model.account?.name ?? '',
                      size: 38,
                      peach: true,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text('Your month', style: titleStyle),
              SizedBox(height: 3),
              Text(
                'Every hour, in view.',
                style: TextStyle(
                  color: mhpColor(context, brandMuted),
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => state.selectMonth(
                      DateTime(month.year, month.month - 1),
                    ),
                    icon: Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => pickMonth(context),
                      child: Text(
                        monthLabel(month),
                        style: TextStyle(
                          color: mhpColor(context, brandInk),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => state.selectMonth(
                      DateTime(month.year, month.month + 1),
                    ),
                    icon: Icon(Icons.chevron_right),
                  ),
                ],
              ),
              OverviewPeriodSwitch(model: model),
              SizedBox(height: 14),
              if (!workspace.writable)
                InfoPanel(
                  'This workspace is read-only. You can view entries, but cannot add or change hours.',
                ),
              if (state.calendarFailure != null)
                _RangeFailure(
                  title: 'Month hours could not be refreshed.',
                  failure: state.calendarFailure!,
                  onRetry: state.refresh,
                ),
              if (state.weeksFailure != null)
                _RangeFailure(
                  title:
                      'Weekly breakdown and overtime could not be refreshed.',
                  failure: state.weeksFailure!,
                  onRetry: state.refresh,
                ),
              if (state.stale &&
                  (totals != null || state.overtimeMinutes != null))
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Showing previously loaded values. ${_updatedLabel(state.snapshot)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: mhpColor(context, brandMuted),
                    ),
                  ),
                ),
              if (awaitingCalendar || awaitingWeeks)
                OverviewSkeleton(
                  monthly: true,
                  contentOnly: true,
                  calendarRows: monthCells(month).length ~/ 7,
                )
              else ...[
                LayoutBuilder(
                  builder: (context, c) {
                    final cards = [
                      _MetricCard(
                        loading: awaitingCalendar,
                        label: 'Hours logged',
                        value: totals == null
                            ? 'Unavailable'
                            : compactHours(totals.totalMinutes),
                        detail: totals == null
                            ? 'Refresh to load month hours'
                            : '${totals.workedDays} ${totals.workedDays == 1 ? 'worked day' : 'worked days'}',
                        icon: Icons.schedule,
                        color: Color(0xfffff0e5),
                        ink: mhpColor(context, brandInk),
                      ),
                      _MetricCard(
                        loading: awaitingWeeks,
                        label: 'Overtime',
                        value: state.overtimeMinutes == null
                            ? 'Unavailable'
                            : '+${compactHours(state.overtimeMinutes!)}',
                        detail: 'Across full weeks',
                        icon: Icons.bar_chart,
                        color: brandGreen,
                        ink: mhpColor(context, overtimeInk),
                      ),
                    ];
                    if (MediaQuery.textScalerOf(context).scale(1) > 1.35 ||
                        c.maxWidth < 300) {
                      return Column(
                        children: [cards[0], SizedBox(height: 10), cards[1]],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards[0]),
                        SizedBox(width: 12),
                        Expanded(child: cards[1]),
                      ],
                    );
                  },
                ),
                SizedBox(height: 12),
                _Card(
                  loading: awaitingCalendar || awaitingWeeks,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bar_chart, size: 19),
                          SizedBox(width: 10),
                          Text('Daily average'),
                        ],
                      ),
                      Text(
                        totals == null
                            ? 'Unavailable'
                            : durationLabel(totals.averageMinutes),
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14),
                _Card(
                  loading: awaitingCalendar || awaitingWeeks,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Month at a glance', style: _sectionStyle),
                      SizedBox(height: 12),
                      MonthCalendar(
                        month: month,
                        today: workspaceToday(workspace.timezone),
                        selected: selected,
                        entries: totals?.entries ?? [],
                        available: calendarReady,
                        onSelect: calendarReady
                            ? (date) {
                                if (dateKey(date) == dateKey(selected) &&
                                    workspace.writable &&
                                    !state.loadingCalendar &&
                                    state.calendarFailure == null) {
                                  if (entry != null) {
                                    onEntry(entry);
                                  } else {
                                    onAddDate?.call(date);
                                  }
                                } else {
                                  state.selectDay(date);
                                }
                              }
                            : null,
                      ),
                      if (totals?.entries.isEmpty == true)
                        Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'No hours logged this month. Select a date to add hours.',
                            style: TextStyle(
                              color: mhpColor(context, brandMuted),
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                _Card(
                  loading: awaitingCalendar || awaitingWeeks,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 16,
                        runSpacing: 5,
                        children: [
                          Text(
                            '${shortDays[selected.weekday - 1]}, ${shortDate(selected)}',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (entry != null)
                            Text(
                              durationLabel(entry.netMinutes),
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                        ],
                      ),
                      if (entry != null) ...[
                        Text(
                          '${entry.start}–${entry.end} · ${entry.breakMinutes}m ${entry.paidBreak ? 'paid' : 'unpaid'} break',
                          style: TextStyle(
                            fontSize: 13,
                            color: mhpColor(context, brandMuted),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => onEntry(entry),
                            icon: Icon(Icons.chevron_right, size: 18),
                            label: Text('View entry'),
                          ),
                        ),
                      ] else
                        Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            calendarReady
                                ? (workspace.writable
                                      ? 'No recorded entry. Use Add hours below for this date.'
                                      : 'No recorded entry. This workspace is read-only.')
                                : 'Entry dates are unavailable. Refresh before adding hours.',
                            style: TextStyle(
                              color: mhpColor(context, brandMuted),
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                _Card(
                  loading: awaitingCalendar || awaitingWeeks,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Weekly breakdown', style: _sectionStyle),
                      SizedBox(height: 4),
                      Text(
                        workspace.targetMinutes > 0
                            ? '${compactHours(workspace.targetMinutes)} weekly target'
                            : 'Weekly target not set',
                        style: TextStyle(
                          color: mhpColor(context, brandMuted),
                          fontSize: 13,
                        ),
                      ),
                      if (state.snapshot?.fullWeeks == null && !awaitingWeeks)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Weekly totals unavailable. Refresh to load them.',
                          ),
                        ),
                      for (var i = 0; i < weekRows.length; i++) ...[
                        if (i > 0) Divider(),
                        WeeklyBreakdownRow(
                          week: weekRows[i],
                          scaleMinutes: weekRows.fold<int>(0, (largest, week) {
                            final value =
                                week.minutes > (week.targetMinutes ?? 0)
                                ? week.minutes
                                : (week.targetMinutes ?? 0);
                            return value > largest ? value : largest;
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 12),
                _Card(
                  color: Color(0xfffff0e5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: mhpColor(context, brandAction),
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How overtime is counted',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Overtime is positive weekly excess across full weeks touching this month, including days outside the month.',
                              style: TextStyle(
                                color: mhpColor(context, brandMuted),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14),
                _Card(
                  loading: awaitingCalendar || awaitingWeeks,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Monthly breaks', style: _sectionStyle),
                      SizedBox(height: 8),
                      _BreakRow(
                        'Breaks recorded',
                        totals == null ? 'Unavailable' : '${totals.breakCount}',
                      ),
                      Divider(),
                      _BreakRow(
                        'Paid breaks included',
                        totals == null
                            ? 'Unavailable'
                            : compactHours(totals.paidMinutes),
                      ),
                      Divider(),
                      _BreakRow(
                        'Unpaid breaks deducted',
                        totals == null
                            ? 'Unavailable'
                            : compactHours(totals.unpaidMinutes),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const _sectionStyle = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 18,
  fontWeight: FontWeight.w800,
  letterSpacing: -.4,
);
String _updatedLabel(MonthlySnapshot? snapshot) {
  final time = snapshot?.calendarUpdated ?? snapshot?.weeksUpdated;
  return time == null
      ? ''
      : 'Last updated ${time.day} ${months[time.month - 1]}, ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}.';
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.color = Colors.white,
    this.loading = false,
  });
  final bool loading;
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: mhpColor(context, color),
      border: Border.all(
        color: mhpColor(context, brandBorder).withValues(alpha: .65),
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: SkeletonRegion(loading: loading, child: child),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    this.loading = false,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    required this.ink,
  });
  final bool loading;
  final String label, value, detail;
  final IconData icon;
  final Color color, ink;
  @override
  Widget build(BuildContext context) => _Card(
    color: color,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: label == 'Overtime' ? ink : mhpColor(context, brandAction),
              size: 22,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 13, color: ink)),
            ),
          ],
        ),
        SizedBox(height: 7),
        SkeletonRegion(
          loading: loading,
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.textScalerOf(context).scale(40),
            child: Text(
              value,
              style: titleStyle.copyWith(
                fontSize: 28,
                color: ink,
                letterSpacing: -.8,
              ),
            ),
          ),
        ),
        SizedBox(height: 4),
        SkeletonRegion(
          loading: loading,
          child: Text(
            detail,
            style: TextStyle(
              color: mhpColor(context, brandMuted),
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

class _BreakRow extends StatelessWidget {
  const _BreakRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      children: [
        Text(label, style: TextStyle(fontSize: 13)),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    ),
  );
}

class _RangeFailure extends StatelessWidget {
  const _RangeFailure({
    required this.title,
    required this.failure,
    required this.onRetry,
  });
  final String title;
  final ApiFailure failure;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
      ErrorNotice(failure),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: onRetry, child: Text('Refresh month')),
      ),
    ],
  );
}

class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.today,
    required this.selected,
    required this.entries,
    required this.available,
    this.onSelect,
  });
  final DateTime month, today, selected;
  final List<HoursEntry> entries;
  final bool available;
  final ValueChanged<DateTime>? onSelect;
  @override
  Widget build(BuildContext context) {
    final entriesByDate = {
      for (final entry in entries) dateKey(entry.date): entry,
    };
    final days = monthCells(month);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    Widget cell(DateTime date) {
      final inside = date.month == month.month;
      final entry = inside ? entriesByDate[dateKey(date)] : null;
      final active = inside && dateKey(date) == dateKey(selected);
      final isToday = dateKey(date) == dateKey(today);
      return Expanded(
        child: Padding(
          padding: EdgeInsets.all(1.5),
          child: Semantics(
            button: inside && onSelect != null,
            selected: active,
            label:
                '${dateKey(date)}${isToday ? ', today' : ''}, ${!inside
                    ? 'outside this month'
                    : !available
                    ? 'entry data unavailable'
                    : entry == null
                    ? 'no recorded entry'
                    : compactHours(entry.netMinutes)}',
            child: InkWell(
              key: ValueKey('month-day-${dateKey(date)}'),
              onTap: inside && onSelect != null ? () => onSelect!(date) : null,
              borderRadius: BorderRadius.circular(7),
              child: Container(
                constraints: BoxConstraints(minHeight: scale > 1.35 ? 76 : 52),
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 1),
                decoration: BoxDecoration(
                  color: active
                      ? brandOrange
                      : entry != null
                      ? mhpColor(context, Color(0xffffeee2))
                      : mhpColor(context, Color(0xfff5f3f0)),
                  borderRadius: BorderRadius.circular(7),
                  border: isToday
                      ? Border.all(
                          color: mhpColor(context, brandAction),
                          width: 2,
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 13,
                        color: active
                            ? brandInk
                            : inside
                            ? mhpColor(context, brandInk)
                            : mhpColor(
                                context,
                                brandMuted,
                              ).withValues(alpha: .6),
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    if (entry != null)
                      Text(
                        compactHours(entry.netMinutes),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: active
                              ? brandInk
                              : mhpColor(context, brandMuted),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      color: mhpColor(context, brandMuted),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 6),
        for (var offset = 0; offset < days.length; offset += 7)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final day in days.skip(offset).take(7)) cell(day)],
          ),
      ],
    );
  }
}

class WeeklyBreakdownRow extends StatelessWidget {
  const WeeklyBreakdownRow({super.key, required this.week, this.scaleMinutes});
  final HoursWeek week;
  final int? scaleMinutes;
  String get status => week.minutes == 0
      ? 'No hours logged'
      : week.targetMinutes == null
      ? 'Target unavailable'
      : week.targetMinutes == 0
      ? 'Target not set'
      : week.variance! > 0
      ? '+${compactHours(week.variance!)} overtime'
      : week.variance! < 0
      ? '${compactHours(-week.variance!)} below target'
      : 'On target';
  @override
  Widget build(BuildContext context) {
    final target = week.targetMinutes ?? 0;
    final rowMaximum = week.minutes > target ? week.minutes : target;
    final maxMinutes = (scaleMinutes ?? 0) > rowMaximum
        ? scaleMinutes!
        : rowMaximum;
    final regular = target > 0
        ? (week.minutes < target ? week.minutes : target)
        : week.minutes;
    final extra = target > 0 && week.minutes > target
        ? week.minutes - target
        : 0;
    final positive = target > 0 && extra > 0;
    return Semantics(
      label: '${weekLabel(week.start)}, ${compactHours(week.minutes)}, $status',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(weekLabel(week.start), style: TextStyle(fontSize: 13)),
                Text(
                  compactHours(week.minutes),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LayoutBuilder(
                      builder: (_, c) => Container(
                        height: 9,
                        color: mhpColor(context, Color(0xffefeeec)),
                        child: Row(
                          children: [
                            if (maxMinutes > 0)
                              Container(
                                width: c.maxWidth * regular / maxMinutes,
                                height: 9,
                                color: brandOrange,
                              ),
                            if (extra > 0)
                              Container(
                                width: c.maxWidth * extra / maxMinutes,
                                height: 9,
                                color: mhpColor(context, overtimeInk),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Flexible(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: positive
                          ? mhpColor(context, Color(0xffe1f2e6))
                          : mhpColor(context, Color(0xfff2f1f1)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        color: positive
                            ? overtimeInk
                            : mhpColor(context, brandMuted),
                        fontWeight: positive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.initial});
  final DateTime initial;
  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int year = widget.initial.year;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        IconButton(
          tooltip: 'Previous year',
          onPressed: year > 1900 ? () => setState(() => year--) : null,
          icon: Icon(Icons.chevron_left),
        ),
        Expanded(child: Text('$year', textAlign: TextAlign.center)),
        IconButton(
          tooltip: 'Next year',
          onPressed: year < 2200 ? () => setState(() => year++) : null,
          icon: Icon(Icons.chevron_right),
        ),
      ],
    ),
    content: SizedBox(
      width: 320,
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 12; i++)
              SizedBox(
                width: 78,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pop(context, DateTime(year, i + 1)),
                  child: Text(months[i]),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel'),
      ),
    ],
  );
}
