import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../shared/widgets.dart';
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
  late final workspace = widget.model.workspace!;
  final note = TextEditingController();
  final mutation = MutationKey();
  List<Timesheet> sheets = [];
  bool loading = true, saving = false, review = false;
  ApiFailure? failure;
  String? notice;
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
      final result = await repository.list(workspace.id, review: review);
      if (mounted) setState(() => sheets = result);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => failure = e);
    } catch (_) {
      if (mounted) {
        setState(
          () => failure = const ApiFailure(
            'invalid_response',
            'Could not load timesheets.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Timesheets')),
    body: PageBody(
      children: [
        if (workspace.canReview)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Manager review'),
            value: review,
            onChanged: loading || saving
                ? null
                : (v) {
                    setState(() => review = v);
                    load();
                  },
          ),
        ErrorNotice(failure),
        Notice(notice),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (sheets.isEmpty) const Notice('No timesheets to show.'),
          for (final sheet in sheets)
            Card(
              child: ListTile(
                title: Text(
                  review
                      ? '${sheet.name ?? 'Team member'} · ${sheet.weekStart}'
                      : 'Week of ${sheet.weekStart}',
                ),
                subtitle: Text(
                  '${sheet.status} · ${durationLabel(sheet.totalMinutes)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ReviewTimesheetScreen(
                        repository: repository,
                        workspace: workspace,
                        id: sheet.id,
                        canReview: review,
                      ),
                    ),
                  );
                  await load();
                },
              ),
            ),
          if (!review && workspace.writable) ...[
            const SizedBox(height: 24),
            Text(
              'Submit week of ${dateKey(widget.model.week)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              enabled: !saving,
              maxLength: 2000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Submission note (optional)',
              ),
            ),
            const Notice('Your manager can review this week after you submit.'),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
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
                          setState(() => notice = 'Timesheet submitted.');
                          await load();
                        }
                      } on ApiFailure catch (e) {
                        if (mounted) setState(() => failure = e);
                      } finally {
                        if (mounted) setState(() => saving = false);
                      }
                    },
              child: Text(saving ? 'Submitting…' : 'Submit for approval'),
            ),
          ],
        ],
        TextButton(
          onPressed: loading || saving ? null : load,
          child: const Text('Reload timesheets'),
        ),
      ],
    ),
  );
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
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> decide(String decision) async {
    if (decision == 'rejected' && note.text.trim().isEmpty) {
      setState(
        () => failure = const ApiFailure(
          'review_note_required',
          'Explain the changes requested in the review note.',
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
      if (mounted) Navigator.pop(context);
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Weekly timesheet')),
    body: PageBody(
      children: [
        if (loading) const Center(child: CircularProgressIndicator()),
        ErrorNotice(failure),
        if (sheet != null) ...[
          Text(
            sheet!.name ?? 'Your timesheet',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text('${sheet!.weekStart} · ${sheet!.status}'),
          const SizedBox(height: 20),
          Text(
            durationLabel(sheet!.totalMinutes),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          for (final entry in sheet!.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${dateKey(entry.date)} · ${entry.start}–${entry.end}',
              ),
              subtitle: Text(durationLabel(entry.netMinutes)),
            ),
          if (sheet!.reviewNote != null) Notice(sheet!.reviewNote),
          if (widget.canReview && widget.workspace.writable) ...[
            TextField(
              controller: note,
              enabled: !saving,
              maxLength: 2000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Review note'),
            ),
            FilledButton(
              onPressed: saving || conflict || loading
                  ? null
                  : () => decide('approved'),
              child: const Text('Approve'),
            ),
            OutlinedButton(
              onPressed: saving || conflict || loading
                  ? null
                  : () => decide('rejected'),
              child: const Text('Request changes'),
            ),
            if (['approved', 'locked'].contains(sheet!.status))
              TextButton(
                onPressed: saving || conflict || loading
                    ? null
                    : () => decide('reopened'),
                child: const Text('Reopen timesheet'),
              ),
          ],
        ],
        TextButton(
          onPressed: loading || saving ? null : load,
          child: const Text('Reload server version'),
        ),
      ],
    ),
  );
}
