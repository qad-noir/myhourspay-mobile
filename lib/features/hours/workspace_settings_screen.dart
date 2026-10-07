import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../shared/widgets.dart';
import '../session/session_model.dart';
import 'models.dart';
import 'overtime_preferences.dart';
import 'repository.dart';

class WorkspaceSettingsScreen extends StatefulWidget {
  const WorkspaceSettingsScreen({super.key, required this.model});
  final SessionModel model;
  @override
  State<WorkspaceSettingsScreen> createState() =>
      _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState extends State<WorkspaceSettingsScreen> {
  final form = GlobalKey<FormState>();
  final weekly = TextEditingController(),
      dailyHours = TextEditingController(),
      dailyMinutes = TextEditingController();
  final mutation = MutationKey();
  late Workspace current;
  late String basis;
  bool saving = false, conflict = false, uncertain = false;
  ApiFailure? failure;
  Json? pendingBody;
  @override
  void initState() {
    super.initState();
    prefill(widget.model.workspace!);
  }

  void prefill(Workspace workspace) {
    current = workspace;
    basis = current.overtimeBasis;
    weekly.text = (current.targetMinutes / 60).toString();
    dailyHours.text = current.contractedDailyMinutes == null
        ? ''
        : '${current.contractedDailyMinutes! ~/ 60}';
    dailyMinutes.text = current.contractedDailyMinutes == null
        ? ''
        : '${current.contractedDailyMinutes! % 60}';
  }

  bool get allowed =>
      current.settingsSupported &&
      current.canManageSettings &&
      current.writable &&
      failure?.status != 403;
  Future<void> reload() async {
    if (saving) return;
    final bearer = widget.model.auth.api.token;
    final workspaceId = current.id;
    setState(() => saving = true);
    try {
      final values = await widget.model.hours.workspaces();
      final fresh = values.where((w) => w.id == current.id).firstOrNull;
      if (fresh == null) {
        throw const ApiFailure(
          'workspace_unavailable',
          'This workspace is no longer available.',
          status: 403,
        );
      }
      if (!mounted ||
          widget.model.auth.api.token != bearer ||
          widget.model.workspace?.id != workspaceId) {
        return;
      }
      setState(() {
        prefill(fresh);
        conflict = uncertain = false;
        pendingBody = null;
        failure = null;
      });
      await widget.model.applyWorkspaceSettings(fresh);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => failure = e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> save() async {
    if (saving || conflict || !allowed) return;
    if (!uncertain) {
      setState(() => failure = null);
      if (!form.currentState!.validate()) return;
      final target = (double.parse(weekly.text) * 60).round();
      final contract = dailyContractMinutes(dailyHours.text, dailyMinutes.text);
      final body = <String, dynamic>{
        'settings_version': current.settingsVersion,
      };
      if (target != current.targetMinutes) {
        body['weekly_target_minutes'] = target;
      }
      if (contract != current.contractedDailyMinutes) {
        body['contracted_daily_minutes'] = contract;
      }
      if (basis != current.overtimeBasis) body['overtime_basis'] = basis;
      if (body.length == 1) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No settings changed.')));
        return;
      }
      pendingBody = body;
    }
    setState(() {
      saving = true;
      failure = null;
    });
    final bearer = widget.model.auth.api.token;
    final workspaceId = current.id;
    try {
      final updated = await widget.model.hours.updateSettings(
        current.id,
        pendingBody!,
        mutation,
      );
      if (!mounted ||
          widget.model.auth.api.token != bearer ||
          widget.model.workspace?.id != workspaceId) {
        return;
      }
      setState(() {
        prefill(updated);
        uncertain = false;
        pendingBody = null;
      });
      await widget.model.applyWorkspaceSettings(updated);
      await widget.model.refreshWorkspaceSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workspace settings saved.')),
        );
        Navigator.pop(context);
      }
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          failure = e;
          uncertain = e.uncertain;
          conflict = e.code == 'workspace_settings_changed';
        });
        form.currentState!.validate();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          uncertain = true;
          failure = const ApiFailure(
            'invalid_response',
            'Save could not be confirmed. Reload the server settings or retry unchanged values.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    weekly.dispose();
    dailyHours.dispose();
    dailyMinutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Workspace preferences')),
    body: Form(
      key: form,
      child: PageBody(
        footer: allowed
            ? FilledButton(
                onPressed: saving || conflict ? null : save,
                child: Text(
                  saving
                      ? 'Saving…'
                      : uncertain
                      ? 'Retry unchanged settings'
                      : 'Save settings',
                ),
              )
            : null,
        children: [
          Text(current.name, style: titleStyle),
          const SizedBox(height: 20),
          if (!current.settingsSupported)
            const InfoPanel(
              'A backend update is required before workspace overtime settings can be saved.',
            ),
          if (current.settingsSupported && !allowed)
            const InfoPanel(
              'Only an owner or administrator of a writable workspace can change these settings.',
            ),
          OvertimePreferences(
            weekly: weekly,
            dailyHours: dailyHours,
            dailyMinutes: dailyMinutes,
            basis: basis,
            enabled: allowed && !saving && !uncertain && !conflict,
            fields: failure?.fields ?? {},
            onBasis: (value) => setState(() {
              basis = value;
              failure = null;
            }),
            onChanged: () => setState(() => failure = null),
          ),
          if (conflict)
            const InfoPanel(
              'Workspace settings changed elsewhere. Reload and review the newer settings before saving again.',
            ),
          if (uncertain)
            const InfoPanel(
              'Save is not confirmed. Retry these unchanged settings, or reload the server settings before making another change.',
            ),
          if (!conflict) ErrorNotice(failure),
          if (conflict || uncertain)
            TextButton(
              onPressed: saving ? null : reload,
              child: const Text('Reload server settings'),
            ),
        ],
      ),
    ),
  );
}
