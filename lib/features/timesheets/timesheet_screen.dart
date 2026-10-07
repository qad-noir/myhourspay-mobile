import '../../shared/overtime_summary.dart';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../shared/widgets.dart';
import '../../shared/hours_widgets.dart';
import '../hours/edit_hours_screen.dart';
import '../hours/models.dart';
import '../hours/repository.dart';
import '../session/session_model.dart';
import 'timesheet_repository.dart';

class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key, required this.model});
  final SessionModel model;
  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  late final repository = TimesheetRepository(widget.model.auth.api);
  Workspace get workspace => widget.model.workspace!;
  String? _settingsVersion;
  final note = TextEditingController();
  final mutation = MutationKey();
  List<Timesheet> sheets = [];
  bool loading = true, saving = false, review = false;
  ApiFailure? failure;
  String? notice;
  @override
  void initState() {
    super.initState();
    _settingsVersion = workspace.settingsVersion;
    load();
  }

  @override
  void didUpdateWidget(covariant TimesheetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_settingsVersion != workspace.settingsVersion) {
      _settingsVersion = workspace.settingsVersion;
      load();
    }
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final result = await repository.list(workspace.id, review: review);
      if (mounted) setState(() => sheets = result);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => failure = e);
    } catch (_) {
      if (mounted) {
        setState(
          () => failure = ApiFailure(
            'invalid_response',
            'Could not load timesheets.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    if (saving ||
        loading ||
        !workspace.writable ||
        !workspace.timesheetsEnabled) {
      return;
    }
    setState(() {
      saving = true;
      failure = null;
      notice = null;
    });
    try {
      await repository.submit(
        workspace.id,
        widget.model.week,
        note.text,
        mutation,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Timesheet submitted.'),
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await load();
      }
    } on ApiFailure catch (e) {
      if (mounted) setState(() => failure = e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheet = sheets
        .where((s) => s.weekStart == dateKey(widget.model.week))
        .firstOrNull;
    final status = sheet?.status ?? 'draft';
    final canSubmit =
        workspace.timesheetsEnabled &&
        workspace.writable &&
        ['draft', 'rejected', 'reopened'].contains(status) &&
        widget.model.page?.entries.isNotEmpty == true;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final submitAction = FilledButton(
      onPressed: saving ? null : submit,
      child: Text(saving ? 'Submitting…' : 'Submit for approval'),
    );
    final showSubmit = !loading && !review && canSubmit;
    return Scaffold(
      bottomNavigationBar: !keyboardOpen && showSubmit
          ? SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, 10, 22, 12),
                child: submitAction,
              ),
            )
          : null,
      body: PageBody(
        padding: EdgeInsets.fromLTRB(22, 22, 22, 12),
        footer: keyboardOpen && showSubmit ? submitAction : null,
        children: [
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('Weekly timesheet', style: titleStyle)),
              if (workspace.canReview)
                IconButton(
                  tooltip: review
                      ? 'Back to my week'
                      : 'Review team timesheets',
                  onPressed: loading || saving
                      ? null
                      : () {
                          setState(() => review = !review);
                          load();
                        },
                  icon: Icon(
                    review ? Icons.person_outline : Icons.group_outlined,
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  weekLabel(widget.model.week),
                  style: TextStyle(
                    color: mhpColor(context, brandMuted),
                    fontSize: 16,
                  ),
                ),
              ),
              StatusBadge(capitalized(status), success: status == 'approved'),
            ],
          ),
          ErrorNotice(failure),
          Notice(notice),
          if (loading)
            Padding(padding: EdgeInsets.only(top: 24), child: LoadingCards())
          else if (review) ...[
            SizedBox(height: 20),
            SectionLabel('TEAM TIMESHEETS'),
            if (sheets.isEmpty)
              InfoPanel('No timesheets are waiting for review.'),
            for (final item in sheets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: InitialAvatar(item.name ?? 'Team member', size: 40),
                title: Text(item.name ?? 'Team member'),
                subtitle: Text(
                  '${item.weekStart} · ${capitalized(item.status)}',
                ),
                trailing: Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ReviewTimesheetScreen(
                        repository: repository,
                        workspace: workspace,
                        id: item.id,
                        canReview: workspace.canReview,
                      ),
                    ),
                  );
                  await load();
                },
              ),
          ] else ...[
            SizedBox(height: 18),
            Text(
              durationLabel(
                sheet?.totalMinutes ?? widget.model.page?.totalMinutes ?? 0,
              ),
              style: totalStyle,
            ),
            Text(
              'Total for week',
              style: TextStyle(color: mhpColor(context, brandMuted)),
            ),
            SizedBox(height: 16),
            if (sheet != null)
              OvertimeSummary(totals: sheet.overtime)
            else if (widget.model.page != null)
              OvertimeSummary(totals: widget.model.page!.overtime),
            Divider(),
            for (final entry
                in widget.model.page?.entries ?? <HoursEntry>[]) ...[
              EntryRow(
                entry: entry,
                onTap: canSubmit
                    ? () async {
                        final saved = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditHoursScreen(
                              model: widget.model,
                              entry: entry,
                            ),
                          ),
                        );
                        if (saved == true) {
                          await widget.model.reload();
                          if (mounted) setState(() {});
                        }
                      }
                    : null,
              ),
              Divider(),
            ],
            if (widget.model.page?.entries.isEmpty ?? true)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: InfoPanel(
                  'Add hours to this week before submitting a timesheet.',
                ),
              ),
            SizedBox(height: 24),
            if (canSubmit) ...[
              Text(
                'Submission note (optional)',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 10),
              TextField(
                controller: note,
                enabled: !saving,
                maxLength: 2000,
                maxLines: 2,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.description_outlined),
                  hintText: 'Add a note for your manager…',
                  counterText: '',
                ),
              ),
              SizedBox(height: 18),
              InfoPanel(
                'Your manager can review this week after you submit.',
                success: true,
              ),
            ] else if (['submitted', 'approved', 'locked'].contains(status))
              InfoPanel(
                'This week is ${capitalized(status).toLowerCase()}. Its hours cannot be edited while locked.',
              ),
          ],
          if (failure != null)
            TextButton(
              onPressed: loading || saving ? null : load,
              child: Text('Try again'),
            ),
        ],
      ),
    );
  }
}

class ReviewTimesheetScreen extends StatefulWidget {
  const ReviewTimesheetScreen({
    super.key,
    required this.repository,
    required this.workspace,
    required this.id,
    required this.canReview,
  });
  final TimesheetRepository repository;
  final Workspace workspace;
  final int id;
  final bool canReview;
  @override
  State<ReviewTimesheetScreen> createState() => _ReviewTimesheetScreenState();
}

class _ReviewTimesheetScreenState extends State<ReviewTimesheetScreen> {
  Timesheet? sheet;
  final note = TextEditingController();
  final mutation = MutationKey();
  ApiFailure? failure;
  bool loading = true, saving = false, conflict = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final result = await widget.repository.detail(
        widget.workspace.id,
        widget.id,
      );
      if (mounted) {
        setState(() {
          sheet = result;
          conflict = false;
        });
      }
    } on ApiFailure catch (e) {
      if (mounted) setState(() => failure = e);
    } catch (_) {
      if (mounted) {
        setState(
          () => failure = ApiFailure(
            'invalid_response',
            'Could not read this timesheet. Please reload.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> decide(String decision) async {
    if (saving ||
        loading ||
        conflict ||
        !widget.canReview ||
        !widget.workspace.canReview ||
        !widget.workspace.writable) {
      return;
    }
    if (decision != 'reopened' && sheet?.status != 'submitted') return;
    if (decision == 'rejected' && note.text.trim().length < 10) {
      setState(
        () => failure = ApiFailure(
          'review_note_required',
          'Explain the requested changes in at least 10 characters.',
        ),
      );
      return;
    }
    setState(() {
      saving = true;
      failure = null;
    });
    try {
      await widget.repository.review(
        widget.workspace.id,
        sheet!,
        decision,
        note.text,
        mutation,
      );
      if (mounted) await load();
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          failure = e;
          conflict = e.status == 409;
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = sheet;
    final allowed =
        widget.canReview &&
        widget.workspace.canReview &&
        widget.workspace.writable;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.maybePop(context)),
      ),
      body: PageBody(
        children: [
          Text(
            widget.canReview ? 'Review timesheet' : 'Weekly timesheet',
            style: titleStyle,
          ),
          SizedBox(height: 24),
          if (loading) LoadingCards(),
          ErrorNotice(failure),
          if (item != null) ...[
            Row(
              children: [
                InitialAvatar(item.name ?? 'Your timesheet', size: 52),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name ?? 'Your timesheet',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        weekLabel(DateTime.parse(item.weekStart)),
                        style: TextStyle(
                          color: mhpColor(context, brandMuted),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                StatusBadge(
                  capitalized(item.status),
                  success: item.status == 'approved',
                ),
              ],
            ),
            SizedBox(height: 24),
            Divider(),
            SizedBox(height: 24),
            SectionLabel('TOTAL HOURS'),
            Text(durationLabel(item.totalMinutes), style: totalStyle),
            const SizedBox(height: 12),
            OvertimeSummary(totals: item.overtime),
            SizedBox(height: 18),
            Panel(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  for (var i = 0; i < item.entries.length; i++) ...[
                    if (i > 0) Divider(),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              shortDays[item.entries[i].date.weekday - 1],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${item.entries[i].start} – ${item.entries[i].end}',
                              style: TextStyle(
                                fontSize: 14,
                                color: mhpColor(context, brandMuted),
                              ),
                            ),
                          ),
                          Text(
                            durationLabel(item.entries[i].netMinutes),
                            style: TextStyle(
                              fontSize: 14,
                              color: mhpColor(context, brandMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.reviewNote != null) Notice(item.reviewNote),
            if (allowed && item.status == 'submitted') ...[
              SizedBox(height: 24),
              SectionLabel('REVIEW NOTE (OPTIONAL)'),
              TextField(
                controller: note,
                enabled: !saving,
                maxLength: 2000,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Add a note…',
                  counterText: '',
                ),
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: saving || conflict || loading
                          ? null
                          : () => decide('approved'),
                      child: Text('Approve'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: mhpColor(context, brandAction)),
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        textStyle: TextStyle(
                          fontFamily: "DM Sans",
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: saving || conflict || loading
                          ? null
                          : () => decide('rejected'),
                      child: Text(
                        'Request changes',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (allowed && ['approved', 'locked'].contains(item.status))
              TextButton(
                onPressed: saving || conflict || loading
                    ? null
                    : () => decide('reopened'),
                child: Text('Reopen timesheet'),
              ),
          ],
          if (conflict || failure != null)
            TextButton(
              onPressed: loading || saving ? null : load,
              child: Text('Reload server version'),
            ),
        ],
      ),
    );
  }
}
