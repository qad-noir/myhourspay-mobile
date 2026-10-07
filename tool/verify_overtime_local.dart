import 'dart:io';

import 'package:timezone/data/latest.dart' as tz;
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/hours/models.dart';
import 'package:myhourspay/features/hours/repository.dart';

/// Creates only isolated local QA records, never production data. No secrets output.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: verify_overtime_local <local API base> <credential file>',
    );
    exitCode = 2;
    return;
  }
  final environment = ApiEnvironment.parse('development', args[0]);
  if (!['127.0.0.1', 'localhost'].contains(environment.base.host)) {
    throw StateError('Local hosts only.');
  }
  tz.initializeTimeZones();
  final credentials = await File(args[1]).readAsString();
  final sections = credentials.split(RegExp(r'^#login[-\s]*', multiLine: true));
  final text = sections.length > 1
      ? sections.firstWhere((s) => s.trimLeft().startsWith('local'))
      : throw StateError('Local credential section required.');
  final email = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}')
      .firstMatch(text)
      ?.group(0);
  final password = RegExp(
    r'^password\s*[:=]\s*(.+)$',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(text)?.group(1)?.trim();
  if (email == null || password == null) {
    throw StateError('Local credentials unavailable.');
  }
  final api = ApiClient(environment), mutation = MutationKey();
  final auth = AuthRepository(api), hours = HoursRepository(api);
  try {
    final login = await auth.login(
      email,
      password,
      'Flutter local overtime QA',
    );
    if (login.status != 'authenticated') {
      throw StateError('Local account requires authentication completion.');
    }
    api.token = login.accessToken;
    final before = await hours.workspaces();
    if (before.isNotEmpty && !before.any((w) => w.settingsSupported)) {
      throw StateError(
        'Local backend contract 2.2 not ready; no writes attempted.',
      );
    }
    final workspace = await hours.createWorkspace({
      'name': 'Flutter overtime QA ${DateTime.now().millisecondsSinceEpoch}',
      'position': 'QA tester',
      'default_break_minutes': 30,
      'default_break_type': 'unpaid',
      'weekly_target_minutes': 2400,
      'overtime_basis': 'daily',
      'contracted_daily_minutes': 480,
    });
    if (!workspace.settingsSupported) {
      throw StateError(
        'Created workspace lacks contract 2.2 settings support; no hours written.',
      );
    }
    // Separate week avoids the report regression's September/October dates.
    final start = DateTime(2026, 11, 16);
    for (var i = 0; i < 5; i++) {
      await hours.save(
        workspace.id,
        HoursDraft(
          date: DateTime(start.year, start.month, start.day + i),
          start: '09:00',
          end: i == 0
              ? '19:30'
              : i == 1
              ? '16:00'
              : '16:30',
          breakMinutes: 30,
          paidBreak: i == 1,
          notes: 'Isolated Flutter overtime verification',
        ),
        MutationKey(),
      );
    }
    final daily = await hours.week(workspace.id, start);
    if (daily.totalMinutes != 2280 ||
        daily.overtimeMinutes != 120 ||
        daily.overtime.weeklyMinutes != 0 ||
        daily.weeks.single.variance != -120) {
      throw StateError('Daily fixture totals mismatch.');
    }
    final body = {
      'settings_version': workspace.settingsVersion,
      'overtime_basis': 'weekly',
    };
    final weeklyWorkspace = await hours.updateSettings(
      workspace.id,
      body,
      mutation,
    );
    final replay = await hours.updateSettings(workspace.id, body, mutation);
    if (replay.settingsVersion != weeklyWorkspace.settingsVersion) {
      throw StateError('Settings replay mismatch.');
    }
    final weekly = await hours.week(workspace.id, start);
    if (weekly.overtimeMinutes != 0 ||
        weekly.overtime.dailyMinutes != 120 ||
        weekly.totalMinutes != 2280) {
      throw StateError('Weekly fixture mismatch.');
    }
    for (final record in daily.entries) {
      final after = weekly.entries.singleWhere((e) => e.id == record.id);
      if (after.version != record.version ||
          after.start != record.start ||
          after.end != record.end ||
          after.paidBreak != record.paidBreak ||
          after.netMinutes != record.netMinutes) {
        throw StateError('Historical entry changed.');
      }
    }
    var conflict = false;
    try {
      await hours.updateSettings(workspace.id, {
        'settings_version': workspace.settingsVersion,
        'contracted_daily_minutes': 450,
      }, MutationKey());
    } on ApiFailure catch (e) {
      conflict = e.status == 409 && e.code == 'workspace_settings_changed';
    }
    if (!conflict) throw StateError('Stale settings accepted.');
    await hours.updateSettings(workspace.id, {
      'settings_version': weeklyWorkspace.settingsVersion,
      'contracted_daily_minutes': 450,
      'overtime_basis': 'daily',
    }, MutationKey());
    final halfHourContract = await hours.week(workspace.id, start);
    if (halfHourContract.overtimeMinutes != 150) {
      throw StateError('450-minute contract mismatch.');
    }
    final latest = (await hours.workspaces()).singleWhere(
      (w) => w.id == workspace.id,
    );
    final reportWeeklySettings = await hours.updateSettings(workspace.id, {
      'settings_version': latest.settingsVersion,
      'contracted_daily_minutes': 480,
      'overtime_basis': 'weekly',
    }, MutationKey());
    final reportEnds = {
      '2026-09-01': '16:30',
      '2026-09-02': '16:30',
      '2026-09-03': '17:15',
      '2026-09-04': '17:45',
      '2026-09-05': '15:30',
      '2026-09-07': '16:15',
      '2026-09-08': '16:30',
      '2026-09-09': '16:00',
      '2026-09-10': '14:45',
      '2026-09-11': '15:45',
      '2026-09-14': '15:30',
      '2026-09-15': '14:45',
      '2026-09-16': '14:45',
      '2026-09-17': '15:30',
      '2026-09-18': '14:45',
      '2026-09-21': '17:30',
      '2026-09-22': '17:00',
      '2026-09-23': '15:45',
      '2026-09-24': '15:45',
      '2026-09-25': '16:00',
      '2026-09-28': '16:00',
      '2026-09-29': '15:00',
      '2026-09-30': '15:30',
      '2026-10-01': '15:15',
      '2026-10-02': '17:45',
      '2026-10-05': '16:45',
      '2026-10-06': '15:15',
    };
    for (final record in reportEnds.entries) {
      await hours.save(
        workspace.id,
        HoursDraft(
          date: DateTime.parse(record.key),
          start: '06:15',
          end: record.value,
          breakMinutes: 30,
          paidBreak: false,
          notes: '',
        ),
        MutationKey(),
      );
    }
    final reportWeekly = await hours.range(
      workspace.id,
      DateTime(2026, 9, 1),
      DateTime(2026, 10, 31),
    );
    if (reportWeekly.entries.length != 27 ||
        reportWeekly.totalMinutes != 14955 ||
        reportWeekly.overtimeMinutes != 1845 ||
        reportWeekly.overtime.dailyMinutes != 1995 ||
        !reportWeekly.weeks.first.partial) {
      throw StateError('27-entry Weekly report mismatch.');
    }
    await hours.updateSettings(workspace.id, {
      'settings_version': reportWeeklySettings.settingsVersion,
      'overtime_basis': 'daily',
    }, MutationKey());
    final reportDaily = await hours.range(
      workspace.id,
      DateTime(2026, 9, 1),
      DateTime(2026, 10, 31),
    );
    if (reportDaily.overtimeMinutes != 1995 ||
        reportDaily.overtime.weeklyMinutes != 1845 ||
        reportDaily.totalMinutes != 14955) {
      throw StateError('27-entry Daily report mismatch.');
    }
    for (final record in reportWeekly.entries) {
      final after = reportDaily.entries.singleWhere(
        (entry) => entry.id == record.id,
      );
      if (after.version != record.version ||
          after.netMinutes != record.netMinutes ||
          after.start != record.start ||
          after.end != record.end) {
        throw StateError('Report entry changed after preference save.');
      }
    }
    stdout.writeln(
      'LOCAL REPORT PASS: 27 records, 14955 net, 1995 Daily, 1845 Weekly; partial boundary; entry versions unchanged.',
    );
    stdout.writeln(
      'LOCAL PASS: workspace ${workspace.id}; 2280 worked, daily 120, weekly 0, variance -120; identical replay; stale settings 409; entry versions unchanged; 450-minute contract daily overtime 150.',
    );
    stdout.writeln(
      'Isolated QA workspace retained for website inspection; no production writes.',
    );
  } on ApiFailure catch (e) {
    stderr.writeln('LOCAL FAIL: HTTP ${e.status}; code=${e.code}');
    exitCode = 1;
  } on StateError catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } finally {
    if (api.token != null) {
      try {
        await auth.logout();
      } catch (_) {}
    }
    api.close();
  }
}
