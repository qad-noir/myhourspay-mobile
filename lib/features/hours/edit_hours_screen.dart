import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../shared/widgets.dart';
import '../../shared/hours_widgets.dart';
import '../session/session_model.dart';
import 'models.dart';
import 'repository.dart';

class EditHoursScreen extends StatefulWidget {
  const EditHoursScreen({
    super.key,
    required this.model,
    this.entry,
    this.initialDate,
    this.initialProjectId,
  });
  final SessionModel model;
  final HoursEntry? entry;
  final DateTime? initialDate;
  final int? initialProjectId;
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
  late DateTime date = existing?.date ?? widget.initialDate ?? initialDate();
  DateTime initialDate() {
    final today = workspaceToday(workspace.timezone);
    return weekStart(today) == widget.model.week ? today : widget.model.week;
  }

  late bool paid = existing?.paidBreak ?? workspace.paidBreak,
      billable = existing?.billable ?? false;
  late int? projectId = existing?.projectId ?? widget.initialProjectId;
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
    } catch (_) {
      if (mounted) {
        setState(
          () => projectFailure = const ApiFailure(
            'invalid_response',
            'Could not read projects. Please try again.',
          ),
        );
      }
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

  Future<void> pickTime(TextEditingController controller) async {
    final value = HoursDraft.clock(controller.text) ?? 540;
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value ~/ 60, minute: value % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (result != null) {
      setState(
        () => controller.text =
            '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  Widget timeField(
    TextEditingController controller,
    String label,
    String key,
  ) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: saving ? null : () => pickTime(controller),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.schedule),
            semanticCounterText: label,
          ),
          validator: (_) => fields[key],
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final from = HoursDraft.clock(start.text), to = HoursDraft.clock(end.text);
    final total = from == null || to == null
        ? 0
        : (to - from - (paid ? 0 : int.tryParse(breaks.text) ?? 0)).clamp(
            0,
            1440,
          );
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final saveAction = FilledButton(
      onPressed: saving || conflict || !workspace.writable ? null : save,
      child: Text(
        saving
            ? 'Saving…'
            : existing == null
            ? 'Save hours'
            : 'Update hours',
      ),
    );
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        bottomNavigationBar: keyboardOpen
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                  child: saveAction,
                ),
              ),
        appBar: AppBar(
          leading: BackButton(
            onPressed: saving ? null : () => Navigator.maybePop(context),
          ),
          title: Text(existing == null ? 'Add hours' : 'Update hours'),
          actions: [
            if (workspace.projectsEnabled)
              PopupMenuButton<bool>(
                tooltip: 'Billing options',
                enabled: !saving,
                initialValue: billable,
                onSelected: (v) => setState(() => billable = v),
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(
                    value: true,
                    checked: billable,
                    child: const Text('Billable'),
                  ),
                  CheckedPopupMenuItem(
                    value: false,
                    checked: !billable,
                    child: const Text('Not billable'),
                  ),
                ],
              ),
          ],
        ),
        body: Form(
          key: form,
          child: PageBody(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
            footer: keyboardOpen ? saveAction : null,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                  foregroundColor: brandInk,
                ),
                onPressed: saving
                    ? null
                    : () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setState(() => date = d);
                      },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  '${['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][date.weekday - 1]}, ${shortDate(date)}',
                ),
              ),
              if (fields['work_date'] != null)
                Text(
                  fields['work_date']!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  timeField(start, 'Start time', 'start_time'),
                  const SizedBox(width: 16),
                  timeField(end, 'End time', 'end_time'),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Break', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: breaks,
                enabled: !saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.coffee_outlined),
                  suffixText: 'min',
                ),
                onChanged: (_) => setState(() {}),
                validator: (_) => fields['break_minutes'],
              ),
              const SizedBox(height: 16),
              const Text('Paid / Unpaid', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final value in [true, false])
                    Expanded(
                      child: Semantics(
                        selected: paid == value,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: brandInk,
                            backgroundColor: paid == value
                                ? brandPeach
                                : const Color(0xfff0eeeb),
                            side: BorderSide(
                              color: paid == value ? brandOrange : brandBorder,
                            ),
                          ),
                          onPressed: saving
                              ? null
                              : () => setState(() => paid = value),
                          child: Text(value ? 'Paid' : 'Unpaid'),
                        ),
                      ),
                    ),
                ],
              ),
              if (workspace.projectsEnabled) ...[
                const SizedBox(height: 16),
                const Text(
                  'Project (optional)',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
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
                    prefixIcon: const Icon(Icons.folder_outlined),
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
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: saving
                      ? null
                      : (v) => setState(() => projectId = v),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Notes (optional)', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: notes,
                enabled: !saving,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add a note…',
                  prefixIcon: Icon(Icons.description_outlined),
                  counterText: '',
                ),
                validator: (_) => fields['notes'],
              ),
              const SizedBox(height: 18),
              Panel(
                color: brandPeach,
                borderColor: brandPeach,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total hours', style: TextStyle(fontSize: 14)),
                    Text(
                      durationLabel(total),
                      style: totalStyle.copyWith(fontSize: 32),
                    ),
                    const Text(
                      'Preview · confirmed when saved',
                      style: TextStyle(fontSize: 11, color: brandMuted),
                    ),
                  ],
                ),
              ),
              ErrorNotice(failure),
              if (failure?.uncertain == true)
                const Notice(
                  'Save is not confirmed. Retry unchanged values, or return to the week and refresh first.',
                ),
              if (conflict)
                OutlinedButton(
                  onPressed: reloadConflict,
                  child: const Text('Reload server version'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
