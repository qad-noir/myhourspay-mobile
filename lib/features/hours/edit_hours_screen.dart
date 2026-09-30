import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../shared/widgets.dart';
import '../session/session_model.dart';
import 'models.dart';
import 'repository.dart';

class EditHoursScreen extends StatefulWidget {
  const EditHoursScreen({super.key, required this.model, this.entry});
  final SessionModel model;
  final HoursEntry? entry;
  @override
  State<EditHoursScreen> createState() => _EditHoursScreenState();
}

class _EditHoursScreenState extends State<EditHoursScreen> {
  final form = GlobalKey<FormState>();
  late final workspace = widget.model.workspace!;
  late HoursEntry? existing = widget.entry;
  late final start = TextEditingController(text: existing?.start ?? '09:00');
  late final end = TextEditingController(text: existing?.end ?? '17:00');
  late final breaks = TextEditingController(
    text: '${existing?.breakMinutes ?? workspace.defaultBreak}',
  );
  late final notes = TextEditingController(text: existing?.notes ?? '');
  late DateTime date = existing?.date ?? widget.model.week;
  late bool paid = existing?.paidBreak ?? workspace.paidBreak,
      billable = existing?.billable ?? false;
  late int? projectId = existing?.projectId;
  List<Project> projects = [];
  bool saving = false, projectsLoading = false, conflict = false;
  ApiFailure? failure, projectFailure;
  final mutation = MutationKey();
  Map<String, String> fields = {};
  @override
  void initState() {
    super.initState();
    if (workspace.projectsEnabled) loadProjects();
  }

  Future<void> loadProjects() async {
    setState(() {
      projectsLoading = true;
      projectFailure = null;
    });
    try {
      final result = await widget.model.hours.projects(workspace.id);
      if (mounted) setState(() => projects = result);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => projectFailure = e);
    } finally {
      if (mounted) setState(() => projectsLoading = false);
    }
  }

  @override
  void dispose() {
    start.dispose();
    end.dispose();
    breaks.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || conflict) return;
    final draft = HoursDraft(
      date: date,
      start: start.text.trim(),
      end: end.text.trim(),
      breakMinutes: int.tryParse(breaks.text) ?? -1,
      paidBreak: paid,
      notes: notes.text,
      projectId: projectId,
      billable: billable,
    );
    fields = draft.validate();
    if (!form.currentState!.validate()) return;
    setState(() {
      saving = true;
      failure = null;
    });
    try {
      await widget.model.hours.save(
        workspace.id,
        draft,
        mutation,
        existing: existing,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          failure = e;
          conflict = e.status == 409;
          fields = e.fields.map((k, v) => MapEntry(k, v.join(' ')));
          form.currentState!.validate();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => failure = const ApiFailure(
            'invalid_response',
            'Save could not be confirmed. Reload your week before making a new change.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> reloadConflict() async {
    // Keep this form intact until the user explicitly chooses the latest server entry.
    await widget.model.reload();
    if (!mounted) return;
    if (widget.model.failure != null) {
      setState(() => failure = widget.model.failure);
      return;
    }
    final latest = widget.model.page?.entries
        .where((e) => e.id == existing?.id)
        .firstOrNull;
    if (latest == null || failure?.code == 'timesheet_locked') {
      Navigator.pop(context);
      return;
    }
    final replace = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Use the server version?'),
        content: const Text(
          'This replaces the unsaved values in this form. Nothing will be saved automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep my draft'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Load latest'),
          ),
        ],
      ),
    );
    if (replace != true || !mounted) return;
    setState(() {
      existing = latest;
      date = latest.date;
      start.text = latest.start;
      end.text = latest.end;
      breaks.text = '${latest.breakMinutes}';
      notes.text = latest.notes;
      paid = latest.paidBreak;
      projectId = latest.projectId;
      billable = latest.billable;
      conflict = false;
      failure = null;
      fields = {};
    });
  }

  Widget field(
    TextEditingController controller,
    String label,
    String key, {
    TextInputType? keyboard,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      controller: controller,
      enabled: !saving,
      maxLength: maxLength,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
      validator: (_) => fields[key],
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'Add hours' : 'Update hours'),
      ),
      body: Form(
        key: form,
        child: PageBody(
          children: [
            Text(workspace.name),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      final value = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (value != null && mounted) {
                        setState(() => date = value);
                      }
                    },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Work date: ${dateKey(date)}'),
            ),
            if (fields['work_date'] != null) Notice(fields['work_date']),
            const SizedBox(height: 20),
            field(
              start,
              'Start time (HH:mm)',
              'start_time',
              keyboard: TextInputType.datetime,
            ),
            field(
              end,
              'End time (HH:mm)',
              'end_time',
              keyboard: TextInputType.datetime,
            ),
            field(
              breaks,
              'Break minutes',
              'break_minutes',
              keyboard: TextInputType.number,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Paid break'),
              value: paid,
              onChanged: saving ? null : (v) => setState(() => paid = v),
            ),
            const SizedBox(height: 20),
            if (workspace.projectsEnabled) ...[
              if (projectsLoading) const LinearProgressIndicator(),
              ErrorNotice(projectFailure),
              if (projectFailure != null)
                TextButton(
                  onPressed: loadProjects,
                  child: const Text('Reload projects'),
                ),
              DropdownButtonFormField<int>(
                key: ValueKey(projectId),
                initialValue: projectId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Project (optional)',
                  errorText: fields['project_id'],
                ),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('No project'),
                  ),
                  if (projectId != null &&
                      !projects.any((p) => p.id == projectId))
                    DropdownMenuItem(
                      value: projectId,
                      child: const Text('Current project (unavailable)'),
                    ),
                  for (final p in projects)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: saving ? null : (v) => setState(() => projectId = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Billable'),
                value: billable,
                onChanged: saving ? null : (v) => setState(() => billable = v),
              ),
              const SizedBox(height: 20),
            ],
            field(
              notes,
              'Notes (optional)',
              'notes',
              keyboard: TextInputType.multiline,
              maxLength: 500,
            ),
            const Text(
              'MHP calculates your saved hours. Overnight shifts are not supported.',
            ),
            ErrorNotice(failure),
            if (failure?.uncertain == true)
              const Notice(
                'This save is not confirmed. Retry unchanged values to reuse the same request key, or return to the week and reload first.',
              ),
            if (conflict)
              OutlinedButton(
                onPressed: reloadConflict,
                child: const Text('Reload server version'),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: saving || conflict ? null : save,
              child: Text(
                saving
                    ? 'Saving…'
                    : existing == null
                    ? 'Save hours'
                    : 'Update hours',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
