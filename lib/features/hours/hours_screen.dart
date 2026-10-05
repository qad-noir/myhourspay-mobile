import 'package:flutter/material.dart';

import '../../shared/widgets.dart';
import '../../shared/overview_skeleton.dart';
import '../../shared/hours_widgets.dart';
import '../account/account_screen.dart';
import '../session/session_model.dart';
import '../timesheets/timesheet_screen.dart';
import 'models.dart';
import 'edit_hours_screen.dart';
import 'week_calendar.dart';
import 'monthly_overview_view.dart';

class HoursScreen extends StatefulWidget {
  const HoursScreen({super.key, required this.model, this.initialTab = 0});
  final SessionModel model;
  final int initialTab;
  @override
  State<HoursScreen> createState() => _HoursScreenState();
}

class _HoursScreenState extends State<HoursScreen> with WidgetsBindingObserver {
  late int tab = widget.initialTab;
  SessionModel get model => widget.model;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (model.workspace != null && model.account != null) {
      model.monthly.bind(model.account!.id, model.workspace!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && tab == 0) model.ensureOverview();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) model.ensureOverview();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void selectTab(int value) {
    setState(() => tab = value);
    if (value == 0) model.ensureOverview();
  }

  Future<void> edit({HoursEntry? entry, DateTime? initialDate}) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditHoursScreen(
          model: model,
          entry: entry,
          initialDate: initialDate,
        ),
      ),
    );
    if (saved == true) {
      await model.reload();
      if (model.workspace != null && model.week != model.overviewWeek) {
        await model.reloadOverview();
      }
      if (model.workspace != null && model.account != null) {
        await model.monthly.afterMutation(model.account!.id, model.workspace!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            content: Text(
              model.failure == null ? 'Hours saved.' : 'Hours saved. Could not refresh the week; please try refreshing.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = model.workspace!;
    final shownWeek = tab == 0 ? model.overviewWeek : model.week;
    final shownPage = tab == 0 ? model.overviewData : model.page;
    final shownLoading = tab == 0 ? model.overviewLoading : model.loadingWeek;
    final shownFailure = tab == 0 ? model.overviewFailure : model.failure;
    final overviewPending =
        tab == 0 &&
        (model.overviewMonthly
            ? (model.monthly.totals == null &&
                      model.monthly.calendarFailure == null) ||
                  (model.monthly.overtimeMinutes == null &&
                      model.monthly.weeksFailure == null)
            : shownPage == null && shownFailure == null);
    final recent = List<HoursEntry>.of(shownPage?.entries ?? [])
      ..sort((a, b) => b.date.compareTo(a.date));
    final items = [
      ('Overview', Icons.home_outlined, Icons.home),
      ('Hours', Icons.schedule_outlined, Icons.schedule),
      if (w.timesheetsEnabled)
        ('Timesheets', Icons.description_outlined, Icons.description),
      ('Account', Icons.person_outline, Icons.person),
    ];
    final accountTab = items.length - 1;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: mhpColor(context, brandSurface),
                  border: Border(
                    top: BorderSide(color: mhpColor(context, brandBorder)),
                  ),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: Semantics(
                          selected: tab == i,
                          child: InkWell(
                            onTap: () => selectTab(i),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    tab == i ? items[i].$3 : items[i].$2,
                                    color: tab == i
                                        ? mhpColor(context, brandAction)
                                        : mhpColor(context, brandMuted),
                                    size: 23,
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    items[i].$1,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: tab == i
                                          ? mhpColor(context, brandAction)
                                          : mhpColor(context, brandMuted),
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
              ),
            ),
      body: tab == accountTab
          ? AccountScreen(model: model)
          : w.timesheetsEnabled && tab == 2
          ? TimesheetScreen(model: model)
          : Scaffold(
              bottomNavigationBar: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(22, 10, 22, 14),
                  child: overviewPending
                      ? const SkeletonRegion(
                          loading: true,
                          child: SizedBox(height: 52, width: double.infinity),
                        )
                      : FilledButton.icon(
                          onPressed:
                              w.writable &&
                                  !shownLoading &&
                                  (tab != 0 ||
                                      !model.overviewMonthly ||
                                      (model.monthly.totals != null &&
                                          !model.monthly.loadingCalendar &&
                                          model.monthly.calendarFailure ==
                                              null))
                              ? () => edit(
                                  initialDate: tab == 0
                                      ? model.overviewMonthly &&
                                                model.monthly.selectedEntry ==
                                                    null
                                            ? model.monthly.selectedDate
                                            : workspaceToday(w.timezone)
                                      : null,
                                )
                              : null,
                          icon: Icon(Icons.add),
                          label: Text('Add hours'),
                        ),
                ),
              ),
              body: tab == 0 && model.overviewMonthly
                  ? MonthlyOverviewView(
                      model: model,
                      onAccount: () => selectTab(accountTab),
                      onEntry: (entry) => edit(entry: entry),
                    )
                  : overviewPending
                  ? const OverviewSkeleton(monthly: false)
                  : PageBody(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton(
                                  onPressed: model.switchWorkspace,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.business_outlined,
                                        size: 19,
                                        color: mhpColor(context, brandInk),
                                      ),
                                      SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          w.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: mhpColor(context, brandInk),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 14),
                                      Icon(
                                        Icons.expand_more,
                                        size: 19,
                                        color: mhpColor(context, brandInk),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 24),
                            IconButton(
                              tooltip: 'Account and devices',
                              onPressed: () => setState(() => tab = accountTab),
                              icon: InitialAvatar(
                                model.account?.name ?? '',
                                size: 38,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 22),
                        if (tab == 0) ...[
                          OverviewPeriodSwitch(model: model),
                          SizedBox(height: 14),
                        ],
                        Text(
                          'Hello, ${model.account?.name.split(' ').first ?? ''}',
                          style: TextStyle(
                            color: mhpColor(context, brandMuted),
                          ),
                        ),
                        SizedBox(height: 3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tab == 1 ? 'Your hours' : 'Your week',
                                    style: titleStyle,
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    weekLabel(shownWeek),
                                    style: TextStyle(
                                      color: mhpColor(context, brandMuted),
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (shownPage != null)
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      durationLabel(shownPage.totalMinutes),
                                      style: titleStyle.copyWith(fontSize: 24),
                                    ),
                                    if (w.targetMinutes > 0)
                                      Text(
                                        'of ${durationLabel(w.targetMinutes)} target',
                                        style: TextStyle(
                                          color: mhpColor(context, brandMuted),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (tab == 1)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: shownLoading
                                  ? null
                                  : () async {
                                      final date = await selectHoursDate(
                                        context,
                                        model,
                                      );
                                      if (date != null && mounted) {
                                        await model.selectWeek(date);
                                      }
                                    },
                              icon: Icon(Icons.calendar_month_outlined),
                              label: Text('Choose a date'),
                            ),
                          ),
                        SizedBox(height: 16),
                        if (shownPage != null && w.targetMinutes > 0)
                          LinearProgressIndicator(
                            value: (shownPage.totalMinutes / w.targetMinutes)
                                .clamp(0, 1),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                            color: brandOrange,
                            backgroundColor: mhpColor(
                              context,
                              Color(0xffeeece9),
                            ),
                          ),
                        if (!w.writable)
                          Notice(
                            'This workspace is read-only. You can view your hours.',
                          ),
                        ErrorNotice(shownFailure),
                        if (shownLoading)
                          Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: LoadingCards(),
                          )
                        else if (shownPage != null) ...[
                          if (tab == 0) ...[
                            SizedBox(height: 32),
                            WeekChart(
                              week: shownWeek,
                              entries: shownPage.entries,
                              onDayTap: w.writable
                                  ? (day) => edit(
                                      initialDate: day,
                                      entry: shownPage.entries
                                          .where(
                                            (e) =>
                                                dateKey(e.date) == dateKey(day),
                                          )
                                          .firstOrNull,
                                    )
                                  : null,
                            ),
                            SizedBox(height: 22),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tab == 0 ? 'Recent entries' : 'This week',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (tab == 0)
                                TextButton(
                                  onPressed: () {
                                    selectTab(1);
                                    if (model.week != model.overviewWeek) {
                                      model.selectWeek(model.overviewWeek);
                                    }
                                  },
                                  child: Text('See all'),
                                ),
                            ],
                          ),
                          if (shownPage.entries.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: InfoPanel(
                                'No hours this week. Add your first working day.',
                              ),
                            ),
                          for (final e
                              in (tab == 0
                                  ? recent.take(3)
                                  : shownPage.entries)) ...[
                            EntryRow(
                              entry: e,
                              onTap: w.writable ? () => edit(entry: e) : null,
                            ),
                            Divider(),
                          ],
                        ],
                        if (tab == 1 || shownFailure != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                tooltip: 'Previous week',
                                onPressed: shownLoading || tab == 0
                                    ? null
                                    : () => model.moveWeek(-7),
                                icon: Icon(Icons.chevron_left),
                              ),
                              TextButton.icon(
                                onPressed: shownLoading
                                    ? null
                                    : tab == 0
                                    ? model.reloadOverview
                                    : model.reload,
                                icon: Icon(Icons.refresh, size: 18),
                                label: Text('Refresh'),
                              ),
                              IconButton(
                                tooltip: 'Next week',
                                onPressed: shownLoading || tab == 0
                                    ? null
                                    : () => model.moveWeek(7),
                                icon: Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                      ],
                    ),
            ),
    );
  }
}

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.model});
  final SessionModel model;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  int? selected;
  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final selection = m.workspaces
        .where(
          (w) =>
              w.id ==
              (selected ??
                  m.selectedWorkspaceId ??
                  m.workspaces.firstOrNull?.id),
        )
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: m.workspace == null
            ? null
            : IconButton(
                tooltip: 'Close workspace switch',
                onPressed: m.cancelWorkspaceSwitch,
                icon: const Icon(Icons.close),
              ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: m.busy ? null : m.logout,
            icon: Icon(Icons.logout, size: 21),
          ),
        ],
      ),
      body: PageBody(
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton.icon(
              onPressed: m.busy
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CreateWorkspaceScreen(model: m),
                      ),
                    ),
              icon: Icon(
                Icons.add_circle_outline,
                color: mhpColor(context, brandMuted),
              ),
              label: Text(
                'Create workspace',
                style: TextStyle(color: mhpColor(context, brandInk)),
              ),
            ),
            SizedBox(height: 20),
            FilledButton(
              onPressed: m.busy || selection == null
                  ? null
                  : () => m.selectWorkspace(selection),
              child: Text('Continue'),
            ),
          ],
        ),
        children: [
          SizedBox(height: 24),
          Text('Choose your workspace', style: titleStyle),
          SizedBox(height: 8),
          Text(
            'Where are you working today?',
            style: TextStyle(
              color: mhpColor(context, brandMuted),
              fontSize: 16,
            ),
          ),
          SizedBox(height: 30),
          if (m.busy)
            LoadingCards()
          else
            for (final w in m.workspaces)
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Semantics(
                  selected: selection?.id == w.id,
                  button: true,
                  child: InkWell(
                    onTap: () => setState(() => selected = w.id),
                    borderRadius: BorderRadius.circular(11),
                    child: Panel(
                      color: selection?.id == w.id
                          ? mhpColor(context, Color(0xfffff0e7))
                          : mhpColor(context, Color(0x99ffffff)),
                      borderColor: selection?.id == w.id
                          ? brandOrange
                          : mhpColor(context, brandBorder),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: selection?.id == w.id
                                  ? brandOrange
                                  : mhpColor(context, Color(0xffe6e6e7)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.business_outlined,
                              color: selection?.id == w.id
                                  ? Colors.white
                                  : mhpColor(context, brandMuted),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${capitalized(w.role)}${w.currency == null ? '' : ' · ${w.currency}'}${w.writable ? '' : ' · Read-only'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: mhpColor(context, brandMuted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            selection?.id == w.id
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: selection?.id == w.id
                                ? brandOrange
                                : mhpColor(context, brandMuted),
                            size: 23,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          if (!m.busy && m.workspaces.isEmpty && m.failure == null)
            InfoPanel(
              'Your workspace starts here. Create one to begin recording your hours.',
            ),
          ErrorNotice(m.failure),
          Notice(m.notice),
          if (m.failure != null)
            TextButton(
              onPressed: m.busy ? null : m.refreshAccount,
              child: Text('Try again'),
            ),
        ],
      ),
    );
  }
}

class CreateWorkspaceScreen extends StatefulWidget {
  const CreateWorkspaceScreen({super.key, required this.model});
  final SessionModel model;
  @override
  State<CreateWorkspaceScreen> createState() => _CreateWorkspaceScreenState();
}

class _CreateWorkspaceScreenState extends State<CreateWorkspaceScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      position = TextEditingController(),
      breaks = TextEditingController(text: '30'),
      target = TextEditingController(text: '40');
  bool paid = false, uncertain = false;
  Map<String, List<String>> fields = {};

  Future<void> create() async {
    fields = {};
    if (!form.currentState!.validate()) return;
    final success = await widget.model.createWorkspace({
      'name': name.text.trim(),
      'position': position.text.trim(),
      'default_break_minutes': int.parse(breaks.text),
      'default_break_type': paid ? 'paid' : 'unpaid',
      'weekly_target_minutes': (double.parse(target.text) * 60).round(),
    });
    if (!mounted) return;
    if (success) {
      // First-workspace onboarding may have already replaced this route.
      if (Navigator.canPop(context)) Navigator.pop(context);
    } else {
      setState(() {
        fields = widget.model.failure?.fields ?? {};
        uncertain = widget.model.failure?.uncertain == true;
      });
      form.currentState!.validate();
    }
  }

  String? validate(String key, String? value) {
    if (fields[key]?.isNotEmpty == true) return fields[key]!.join(' ');
    final text = value?.trim() ?? '';
    if (key == 'name' || key == 'position') {
      return text.length < 3 || text.length > 100
          ? 'Enter 3–100 characters.'
          : null;
    }
    if (key == 'default_break_minutes') {
      final minutes = int.tryParse(text);
      return minutes == null || minutes < 0 || minutes > 1439
          ? 'Enter 0–1439 minutes.'
          : null;
    }
    final hours = double.tryParse(text);
    if (hours == null || !hours.isFinite || hours < 1 || hours > 168) {
      return 'Enter a weekly target between 1 and 168 hours.';
    }
    if ((hours * 60 - (hours * 60).round()).abs() > 0.000001) {
      return 'Use a target that is a whole number of minutes, for example 37.5 hours.';
    }
    return null;
  }

  @override
  void dispose() {
    name.dispose();
    position.dispose();
    breaks.dispose();
    target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text('Create workspace')),
      body: Form(
        key: form,
        child: PageBody(
          footer: FilledButton(
            onPressed: widget.model.busy || uncertain ? null : create,
            child: Text(widget.model.busy ? 'Creating…' : 'Create workspace'),
          ),
          children: [
            for (final item in [
              (name, 'Workspace name', 'name'),
              (position, 'Your position', 'position'),
              (breaks, 'Default break (minutes)', 'default_break_minutes'),
              (target, 'Weekly target (hours)', 'weekly_target_minutes'),
            ])
              Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: TextFormField(
                  controller: item.$1,
                  enabled: !widget.model.busy && !uncertain,
                  decoration: InputDecoration(labelText: item.$2),
                  keyboardType: item.$1 == target
                      ? TextInputType.numberWithOptions(decimal: true)
                      : item.$1 == breaks
                      ? TextInputType.number
                      : TextInputType.text,
                  validator: (value) => validate(item.$3, value),
                  onChanged: (_) => fields.remove(item.$3),
                ),
              ),
            SwitchListTile(
              title: Text('Paid break by default'),
              value: paid,
              onChanged: widget.model.busy || uncertain
                  ? null
                  : (v) => setState(() => paid = v),
            ),
            ErrorNotice(widget.model.failure),
            if (uncertain)
              Notice(
                'The request may have succeeded. Return to workspaces and reload before creating another.',
              ),
          ],
        ),
      ),
    ),
  );
}
