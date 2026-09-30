import 'package:flutter/material.dart';

import '../../shared/widgets.dart';
import '../account/account_screen.dart';
import '../session/session_model.dart';
import '../timesheets/timesheet_screen.dart';
import 'models.dart';
import 'edit_hours_screen.dart';

class HoursScreen extends StatelessWidget {
  const HoursScreen({super.key, required this.model});
  final SessionModel model;
  Future<void> edit(BuildContext context, {HoursEntry? entry}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditHoursScreen(model: model, entry: entry),
      ),
    );
    if (saved == true) {
      await model.reload();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Hours saved to MHP.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = model.workspace!;
    final entries = model.page?.entries ?? <HoursEntry>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(workspace.name),
        actions: [
          IconButton(
            tooltip: 'Switch workspace',
            onPressed: model.switchWorkspace,
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: 'Account and devices',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AccountScreen(model: model),
              ),
            ),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: PageBody(
        children: [
          Text('Hello, ${model.account?.name ?? ''}'),
          const SizedBox(height: 8),
          Text('Your week', style: Theme.of(context).textTheme.headlineLarge),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous week',
                onPressed: model.loadingWeek ? null : () => model.moveWeek(-7),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${dateKey(model.week)} – ${dateKey(DateTime(model.week.year, model.week.month, model.week.day + 6))}',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Next week',
                onPressed: model.loadingWeek ? null : () => model.moveWeek(7),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Text(
            workspace.timezone,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!workspace.writable)
            const Notice(
              'This workspace is read-only. You can view your hours.',
            ),
          ErrorNotice(model.failure),
          if (model.loadingWeek)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (model.page != null) ...[
            const SizedBox(height: 24),
            Text(
              durationLabel(model.page!.totalMinutes),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            Text('of ${durationLabel(workspace.targetMinutes)} target'),
            const SizedBox(height: 12),
            Semantics(
              label:
                  '${durationLabel(model.page!.totalMinutes)} recorded of ${durationLabel(workspace.targetMinutes)} target',
              child: LinearProgressIndicator(
                value: workspace.targetMinutes <= 0
                    ? 0
                    : (model.page!.totalMinutes / workspace.targetMinutes)
                          .clamp(0, 1),
                color: brandOrange,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 28),
            Text('Daily hours', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Notice('No hours this week. Add your first working day.'),
            for (var day = 0; day < 7; day++)
              _day(
                context,
                DateTime(
                  model.week.year,
                  model.week.month,
                  model.week.day + day,
                ),
                entries,
                workspace.writable,
              ),
            const SizedBox(height: 24),
          ],
          FilledButton.icon(
            onPressed: workspace.writable && !model.loadingWeek
                ? () => edit(context)
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Add hours'),
          ),
          if (workspace.timesheetsEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => TimesheetScreen(model: model),
                  ),
                ),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Timesheets'),
              ),
            ),
          TextButton.icon(
            onPressed: model.loadingWeek ? null : model.reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Reload week'),
          ),
        ],
      ),
    );
  }

  Widget _day(
    BuildContext context,
    DateTime date,
    List<HoursEntry> entries,
    bool writable,
  ) {
    final entry = entries
        .where((e) => dateKey(e.date) == dateKey(date))
        .firstOrNull;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Column(
      children: [
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .035),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${days[date.weekday - 1]}\n${date.day}',
              textAlign: TextAlign.center,
            ),
          ),
          title: Text(
            entry == null ? 'No entry' : '${entry.start} – ${entry.end}',
          ),
          subtitle: entry == null
              ? null
              : Text(
                  entry.notes.isEmpty
                      ? '${entry.breakMinutes}m ${entry.paidBreak ? 'paid' : 'unpaid'} break'
                      : entry.notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: entry == null
              ? null
              : Text(
                  durationLabel(entry.netMinutes),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
          onTap: entry != null && writable
              ? () => edit(context, entry: entry)
              : null,
        ),
      ],
    );
  }
}

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key, required this.model});
  final SessionModel model;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: model.busy ? null : model.logout,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: PageBody(
      children: [
        Text(
          'Choose your workspace',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        const Text('Where are you working today?'),
        const SizedBox(height: 24),
        for (final workspace in model.workspaces)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.business_outlined),
                title: Text(workspace.name),
                subtitle: Text(
                  '${workspace.role} · ${workspace.currency ?? ''}${workspace.writable ? '' : ' · Read-only'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: model.busy
                    ? null
                    : () => model.selectWorkspace(workspace),
              ),
            ),
          ),
        ErrorNotice(model.failure),
        OutlinedButton.icon(
          onPressed: model.busy
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CreateWorkspaceScreen(model: model),
                  ),
                ),
          icon: const Icon(Icons.add),
          label: const Text('Create workspace'),
        ),
        TextButton(
          onPressed: model.busy ? null : model.refreshAccount,
          child: const Text('Reload workspaces'),
        ),
      ],
    ),
  );
}

class CreateWorkspaceScreen extends StatefulWidget {
  const CreateWorkspaceScreen({super.key, required this.model});
  final SessionModel model;
  @override
  State<CreateWorkspaceScreen> createState() => _CreateWorkspaceScreenState();
}

class _CreateWorkspaceScreenState extends State<CreateWorkspaceScreen> {
  final name = TextEditingController(),
      position = TextEditingController(),
      breaks = TextEditingController(text: '30'),
      target = TextEditingController(text: '2400');
  bool paid = false, uncertain = false;
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
      appBar: AppBar(title: const Text('Create workspace')),
      body: PageBody(
        children: [
          for (final item in [
            (name, 'Workspace name'),
            (position, 'Your position'),
            (breaks, 'Default break (minutes)'),
            (target, 'Weekly target (minutes)'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: TextField(
                controller: item.$1,
                enabled: !widget.model.busy && !uncertain,
                decoration: InputDecoration(labelText: item.$2),
              ),
            ),
          SwitchListTile(
            title: const Text('Paid break by default'),
            value: paid,
            onChanged: widget.model.busy || uncertain
                ? null
                : (v) => setState(() => paid = v),
          ),
          ErrorNotice(widget.model.failure),
          if (uncertain)
            const Notice(
              'The request may have succeeded. Return to workspaces and reload before creating another.',
            ),
          FilledButton(
            onPressed: widget.model.busy || uncertain
                ? null
                : () async {
                    final success = await widget.model.createWorkspace({
                      'name': name.text.trim(),
                      'position': position.text.trim(),
                      'default_break_minutes': int.tryParse(breaks.text) ?? -1,
                      'default_break_type': paid ? 'paid' : 'unpaid',
                      'weekly_target_minutes': int.tryParse(target.text) ?? -1,
                    });
                    if (!context.mounted) return;
                    if (success) {
                      Navigator.pop(context);
                    } else if (widget.model.failure?.uncertain == true) {
                      setState(() => uncertain = true);
                    }
                  },
            child: Text(widget.model.busy ? 'Creating…' : 'Create workspace'),
          ),
        ],
      ),
    ),
  );
}
