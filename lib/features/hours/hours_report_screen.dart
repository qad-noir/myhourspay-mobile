import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../shared/hours_widgets.dart';
import '../../shared/overtime_summary.dart';
import '../../shared/widgets.dart';
import '../session/session_model.dart';
import 'models.dart';
import 'monthly_overview_view.dart';
import 'workspace_settings_screen.dart';

class HoursReportScreen extends StatefulWidget {
  const HoursReportScreen({
    super.key,
    required this.model,
    required this.start,
    this.end,
  });
  final SessionModel model;
  final DateTime start;
  final DateTime? end;
  @override
  State<HoursReportScreen> createState() => _HoursReportScreenState();
}

class _HoursReportScreenState extends State<HoursReportScreen>
    with WidgetsBindingObserver {
  late DateTimeRange range;
  HoursPage? page;
  ApiFailure? failure;
  bool loading = true;
  int generation = 0;
  String? version;
  @override
  void initState() {
    super.initState();
    range = DateTimeRange(
      start: widget.start,
      end: widget.end ?? widget.start.add(const Duration(days: 6)),
    );
    version = widget.model.workspace?.settingsVersion;
    widget.model.addListener(settingsChanged);
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  void settingsChanged() {
    if (version != widget.model.workspace?.settingsVersion) {
      version = widget.model.workspace?.settingsVersion;
      page = null;
      load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.model.refreshWorkspaceSettings();
    }
  }

  Future<void> load() async {
    final selected = widget.model.workspace;
    final bearer = widget.model.auth.api.token;
    if (selected == null || bearer == null) return;
    final request = ++generation;
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final result = await widget.model.hours.range(
        selected.id,
        range.start,
        range.end,
      );
      if (mounted &&
          request == generation &&
          widget.model.workspace?.id == selected.id &&
          widget.model.auth.api.token == bearer) {
        setState(() => page = result);
      }
    } on ApiFailure catch (error) {
      if (mounted && request == generation) setState(() => failure = error);
    } catch (_) {
      if (mounted && request == generation) {
        setState(
          () => failure = const ApiFailure(
            'invalid_response',
            'Could not read the server’s report response.',
          ),
        );
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> chooseDates() async {
    final dates = await showDateRangePicker(
      context: context,
      initialDateRange: range,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Report dates',
    );
    if (!mounted ||
        dates == null ||
        (dates.start == range.start && dates.end == range.end)) {
      return;
    }
    setState(() {
      range = dates;
      page = null;
    });
    await load();
  }

  Future<void> changeCalculation() async {
    final refreshed = await widget.model.refreshWorkspaceSettings();
    if (!mounted) return;
    if (!refreshed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load the latest workspace preferences. Check your connection and try again.',
          ),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => WorkspaceSettingsScreen(model: widget.model),
      ),
    );
  }

  @override
  void dispose() {
    ++generation;
    widget.model.removeListener(settingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hours report')),
    body: PageBody(
      fillViewport: false,
      children: [
        Text(widget.model.workspace?.name ?? '', style: titleStyle),
        TextButton.icon(
          onPressed: loading ? null : chooseDates,
          icon: const Icon(Icons.date_range),
          label: Text(
            '${shortDate(range.start)} ${range.start.year} – ${shortDate(range.end)} ${range.end.year}',
          ),
        ),
        TextButton.icon(
          onPressed: loading ? null : changeCalculation,
          icon: const Icon(Icons.tune),
          label: const Text('Change overtime calculation'),
        ),
        if (isConnectionFailure(failure))
          ConnectionNotice(onRetry: load, cached: page != null, busy: loading)
        else
          ErrorNotice(failure),
        if (loading)
          const LoadingCards()
        else if (page != null) ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hours logged'),
                Text(durationLabel(page!.totalMinutes), style: totalStyle),
                Text('${page!.entries.length} recorded entries'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OvertimeSummary(
            totals: page!.overtime,
            dailyScope: 'selected dates',
            weeklyScope: 'selected dates',
          ),
          const SizedBox(height: 20),
          const SectionLabel('WEEKLY BREAKDOWN'),
          for (final week in page!.weeks)
            WeeklyBreakdownRow(week: week, basis: page!.overtime.basis),
          if (page!.weeks.any((week) => week.partial))
            const InfoPanel(
              'The selected dates exclude part of this week. Daily overtime uses only the selected dates. Partial does not mean an entry is incomplete. Weekly totals here also use the selected dates; the weekly target is not prorated.',
            ),
          if (page!.entries.isEmpty)
            const InfoPanel('No entries in the selected dates.'),
        ],
      ],
    ),
  );
}
