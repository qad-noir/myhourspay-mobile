import 'dart:convert';
import 'dart:io';

import 'package:timezone/data/latest.dart' as tz;

import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/hours/models.dart';
import 'package:myhourspay/features/hours/repository.dart';

/// Explicit local integration runner. Uses the same production repositories as UI.
/// Never prints credentials, account details, response bodies or tokens.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/verify_local.dart <local API base> <credential file>',
    );
    exitCode = 2;
    return;
  }
  final environment = ApiEnvironment.parse('development', args[0]);
  if (!['localhost', '127.0.0.1'].contains(environment.base.host)) {
    throw StateError('Local hosts only.');
  }
  tz.initializeTimeZones();
  final text = await File(args[1]).readAsString();
  final email = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}')
      .firstMatch(text)
      ?.group(0);
  final password = RegExp(
    r'^password\s*[:=]\s*(.+)$',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(text)?.group(1)?.trim();
  if (email == null || password == null) {
    throw StateError('Credential file format invalid.');
  }
  final api = ApiClient(environment);
  final auth = AuthRepository(api), hours = HoursRepository(api);
  try {
    final capabilities = await auth.providers();
    final result = await auth.login(
      email,
      password,
      'MHP Dart repository integration',
    );
    api.token = result.accessToken;
    if (result.status != 'authenticated') {
      stdout.writeln('Account requires ${result.status}; no hours written.');
      exitCode = 1;
      return;
    }
    await auth.me();
    final workspaces = await hours.workspaces();
    final workspace = workspaces.where((w) => w.writable).first;
    final start = weekStart(workspaceToday(workspace.timezone));
    final before = await hours.week(workspace.id, start);
    DateTime? day;
    for (var offset = 0; offset < 7; offset++) {
      final candidate = DateTime(start.year, start.month, start.day + offset);
      if (!before.entries.any((e) => dateKey(e.date) == dateKey(candidate))) {
        day = candidate;
        break;
      }
    }
    if (day == null) {
      throw StateError(
        'No unused date in current week. No existing entry modified.',
      );
    }
    final draft = HoursDraft(
      date: day,
      start: '09:00',
      end: '17:00',
      breakMinutes: 30,
      paidBreak: false,
      notes: 'MHP mobile repository verification',
    );
    final mutation = MutationKey();
    final created = await hours.save(workspace.id, draft, mutation);
    final replay = await hours.save(workspace.id, draft, mutation);
    if (created.id != replay.id) {
      throw StateError('Idempotency replay produced another entry.');
    }
    final update = HoursDraft(
      date: day,
      start: '09:00',
      end: '17:30',
      breakMinutes: 30,
      paidBreak: false,
      notes: 'MHP mobile repository verification - updated',
    );
    final updated = await hours.save(
      workspace.id,
      update,
      MutationKey(),
      existing: created,
    );
    var rejectedStale = false;
    try {
      await hours.save(workspace.id, draft, MutationKey(), existing: created);
    } on ApiFailure catch (e) {
      rejectedStale = e.status == 409 && e.code == 'entry_changed';
    }
    if (!rejectedStale) throw StateError('Stale edit was not rejected.');
    final after = await hours.week(workspace.id, start);
    final persisted = after.entries.singleWhere((e) => e.id == created.id);
    if (persisted.netMinutes != 480 ||
        persisted.version != updated.version ||
        after.totalMinutes != before.totalMinutes + 480) {
      throw StateError('Read-back did not match the saved server totals.');
    }
    final report = {
      'api_base': args[0],
      'workspace_id': workspace.id,
      'entry_id': persisted.id,
      'work_date': dateKey(day),
      'start_time': persisted.start,
      'end_time': persisted.end,
      'net_minutes': persisted.netMinutes,
      'idempotency_replay': true,
      'stale_edit_rejected': true,
      'website_verified': false,
      'providers': capabilities,
    };
    await Directory('.local').create(recursive: true);
    await File('.local/integration-result.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    stdout.writeln(
      'PASS: real login, workspace read, hours create/replay/update, stale-edit rejection and server read-back. Website verification pending.',
    );
  } on ApiFailure catch (e) {
    stderr.writeln(
      'FAIL: ${e.code} (HTTP ${e.status}). No credential data logged.',
    );
    exitCode = 1;
  } catch (_) {
    stderr.writeln(
      'FAIL: integration precondition or response assertion. No credential data logged.',
    );
    exitCode = 1;
  } finally {
    if (api.token != null) {
      try {
        await auth.logout();
      } catch (_) {
        stderr.writeln('Probe token revocation could not be confirmed.');
      }
    }
    api.close();
  }
}
