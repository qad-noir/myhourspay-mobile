import 'package:flutter/material.dart';

import '../session/session_model.dart';
import 'models.dart';
import 'repository.dart';

class HoursScreen extends StatelessWidget {
  const HoursScreen({super.key, required this.model});
  final SessionModel model;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('MHP / MyHoursPay'),
        actions: [
          if (model.phase == SessionPhase.authenticated)
            IconButton(
              tooltip: 'Log out of demo',
              onPressed: model.logout,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xfffff0e9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'DEMO • Sample data stays in memory. Nothing is saved to your MHP account.',
                  ),
                ),
                const SizedBox(height: 32),
                if (model.phase != SessionPhase.authenticated) ...[
                  Text(
                    'Your week,\naccounted for.',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xff171421),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Track your working day and see your weekly hours in one place.',
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Account sign-in is awaiting the mobile backend. Explore the hours workflow with a temporary demo workspace.',
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: model.phase == SessionPhase.authenticating
                        ? null
                        : model.enterDemo,
                    child: const Text('Explore demo'),
                  ),
                ] else if (model.workspace == null) ...[
                  Text(
                    'Choose a workspace',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final workspace in model.workspaces)
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const Icon(Icons.work_outline),
                        title: Text(workspace.name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => model.selectWorkspace(workspace),
                      ),
                    ),
                ] else ...[
                  Text(
                    model.workspace!.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: model.switchWorkspace,
                      child: const Text('Switch workspace'),
                    ),
                  ),
                  Text(
                    'This week',
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text('Week of ${dateKey(model.week)} • Monday–Sunday'),
                  const SizedBox(height: 24),
                  if (model.busy)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    Text(
                      durationLabel(
                        model.entries.fold(
                          0,
                          (total, entry) => total + entry.netMinutes,
                        ),
                      ),
                      style: Theme.of(context).textTheme.displaySmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Text('Demo working hours'),
                    const SizedBox(height: 24),
                    if (model.entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: Text(
                          'No hours yet. Add your first working day below.',
                        ),
                      ),
                    for (var day = 0; day < 7; day++)
                      _DayRow(
                        date: DateTime(
                          model.week.year,
                          model.week.month,
                          model.week.day + day,
                        ),
                        entries: model.entries,
                      ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () async {
                        final saved = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => AddHoursScreen(model: model),
                          ),
                        );
                        if (saved == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Added to demo. Not saved to MHP.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add hours'),
                    ),
                    TextButton.icon(
                      onPressed: model.reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reload week'),
                    ),
                  ],
                ],
                if (model.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      model.error!,
                      semanticsLabel: 'Error: ${model.error}',
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

class _DayRow extends StatelessWidget {
  const _DayRow({required this.date, required this.entries});
  final DateTime date;
  final List<HoursEntry> entries;
  @override
  Widget build(BuildContext context) {
    final matching = entries.where((e) => dateKey(e.date) == dateKey(date));
    final entry = matching.isEmpty ? null : matching.first;
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return Column(
      children: [
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${days[date.weekday - 1]} · ${date.day}'),
          subtitle: Text(
            entry == null
                ? 'No entry'
                : '${entry.start}–${entry.end} · ${entry.breakMinutes}m ${entry.paidBreak ? 'paid' : 'unpaid'} break',
          ),
          trailing: entry == null
              ? null
              : Text(
                  durationLabel(entry.netMinutes),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}

class AddHoursScreen extends StatefulWidget {
  const AddHoursScreen({super.key, required this.model});
  final SessionModel model;
  @override
  State<AddHoursScreen> createState() => _AddHoursScreenState();
}

class _AddHoursScreenState extends State<AddHoursScreen> {
  final form = GlobalKey<FormState>();
  final start = TextEditingController(text: '09:00');
  final end = TextEditingController(text: '17:00');
  final breaks = TextEditingController(text: '30');
  final notes = TextEditingController();
  late DateTime date = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  bool paid = false, saving = false;
  String? error;
  Map<String, String> fields = {};
  @override
  void dispose() {
    start.dispose();
    end.dispose();
    breaks.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    final draft = HoursDraft(
      date: date,
      start: start.text.trim(),
      end: end.text.trim(),
      breakMinutes: int.tryParse(breaks.text) ?? -1,
      paidBreak: paid,
      notes: notes.text,
    );
    fields = draft.validate();
    if (!form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.model.add(draft);
      if (mounted) Navigator.pop(context, true);
    } on AppFailure catch (failure) {
      if (mounted) {
        setState(() {
          fields = failure.fields;
          error = failure.message;
          form.currentState!.validate();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not confirm the save. Reload the week before trying again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget field(
    TextEditingController controller,
    String label,
    String key, {
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      controller: controller,
      enabled: !saving,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
      validator: (_) => fields[key],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add hours')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('DEMO • This entry will not appear on the website.'),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final value = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: widget.model.week,
                            lastDate: DateTime(
                              widget.model.week.year,
                              widget.model.week.month,
                              widget.model.week.day + 6,
                            ),
                          );
                          if (value != null) setState(() => date = value);
                        },
                  icon: const Icon(Icons.calendar_today),
                  label: Text('Work date: ${dateKey(date)}'),
                ),
                const SizedBox(height: 24),
                field(
                  start,
                  'Start time (HH:mm)',
                  'start',
                  keyboard: TextInputType.datetime,
                ),
                field(
                  end,
                  'End time (HH:mm)',
                  'end',
                  keyboard: TextInputType.datetime,
                ),
                field(
                  breaks,
                  'Break minutes',
                  'break',
                  keyboard: TextInputType.number,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Paid break'),
                  value: paid,
                  onChanged: saving
                      ? null
                      : (value) => setState(() => paid = value),
                ),
                const SizedBox(height: 20),
                field(
                  notes,
                  'Notes (optional)',
                  'notes',
                  keyboard: TextInputType.multiline,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Saving…' : 'Add to demo'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
