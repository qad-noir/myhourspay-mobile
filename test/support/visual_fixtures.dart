// Deterministic visual fixtures. Test-only: never imported by lib/ or release.
import 'package:flutter/material.dart';
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/auth/auth_screens.dart';
import 'package:myhourspay/features/account/account_screen.dart';
import 'package:myhourspay/features/hours/models.dart';
import 'package:myhourspay/features/hours/hours_screen.dart';
import 'package:myhourspay/features/hours/edit_hours_screen.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/session/session_model.dart';
import 'package:myhourspay/features/timesheets/timesheet_screen.dart';
import 'package:myhourspay/features/timesheets/timesheet_repository.dart';

import 'fixtures.dart';

const visualNames = [
  'sign-in',
  'your-week',
  'add-hours',
  'weekly-timesheet',
  'verify',
  'workspaces',
  'review-timesheet',
  'account',
];
SessionModel visualModel({bool longNames = false}) {
  final w = {
    ...workspace,
    'name': longNames
        ? 'Design Studio International Creative Services'
        : 'Design Studio',
    'features': {'clients_projects': true, 'timesheet_approvals': true},
  };
  final u = {
    ...user,
    'name': longNames ? 'Alexandra Morgan-Smith' : 'Alex Morgan',
    'email': 'alex@example.com',
    'two_factor_enabled': true,
  };
  final entries = List.generate(
    3,
    (i) => {
      ...entry(id: i + 1, date: '2026-09-${28 + i}'),
      'notes': 'Website refresh',
      'project_id': 1,
    },
  );
  final reviewEntries = List.generate(
    5,
    (i) => {...entry(id: i + 1, date: dateKey(DateTime(2026, 9, 28 + i)))},
  );
  final api = ApiClient(
    ApiEnvironment.parse('development', 'http://fixture.invalid/api/v1/mobile'),
    transport: MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/hours')) {
        final start = DateTime.parse(request.url.queryParameters['start']!);
        final end = DateTime.parse(request.url.queryParameters['end']!);
        return response(
          hoursPage(
            entries.where((entry) {
              final date = DateTime.parse(entry['work_date'] as String);
              return !date.isBefore(start) && !date.isAfter(end);
            }).toList(),
          ),
        );
      }
      if (path.endsWith('/projects')) {
        return response({
          'data': [
            {'id': 1, 'name': 'Website refresh'},
          ],
          'meta': {'last_page': 1},
        });
      }
      if (path.endsWith('/auth/sessions')) {
        return response({
          'data': [
            {
              'id': 1,
              'device_name': 'This iPhone',
              'current': true,
              'last_used_at': '2026-09-30T09:41:00Z',
              'expires_at': null,
            },
            {
              'id': 2,
              'device_name': 'Pixel 9',
              'current': false,
              'last_used_at': '2026-09-28T10:00:00Z',
              'expires_at': null,
            },
          ],
        });
      }
      if (path.endsWith('/timesheets/9')) {
        return response({
          'data': {
            'id': 9,
            'status': 'submitted',
            'week_start': '2026-09-28',
            'version': 'fixture-version',
            'total_minutes': 2250,
            'user_name': 'Jamie Lewis',
            'entries': reviewEntries,
          },
        });
      }
      if (path.endsWith('/timesheets')) {
        return response({
          'data': [],
          'meta': {'last_page': 1},
        });
      }
      throw StateError(
        'Unconfigured visual fixture request: ${request.method} $path',
      );
    }),
  );
  return SessionModel(
      AuthRepository(api),
      HoursRepository(api),
      MemorySessionStore(),
    )
    ..overviewMonthly = false
    ..account = Account.fromJson(u)
    ..workspaces = [
      Workspace.fromJson(w),
      Workspace.fromJson({
        ...w,
        'id': 2,
        'name': 'Northside Team',
        'role': 'member',
      }),
    ]
    ..workspace = Workspace.fromJson(w)
    ..week = DateTime(2026, 9, 28)
    ..page = HoursPage.fromJson(hoursPage(entries))
    ..phase = SessionPhase.authenticated
    ..providers = {'google': true, 'apple': true};
}

Widget visualScreen(String name, SessionModel model) => switch (name) {
  'sign-in' => LoginScreen(
    model: model,
    providerActions: {'google': () {}, 'apple': () {}},
  ),
  'your-week' => ListenableBuilder(listenable: model, builder: (_, _) => HoursScreen(model: model)),
  'add-hours' => EditHoursScreen(
    model: model,
    initialDate: DateTime(2026, 9, 30),
    initialProjectId: 1,
  ),
  'weekly-timesheet' => HoursScreen(model: model, initialTab: 2),
  'verify' => ChallengeScreen(model: model, emailVerification: false),
  'workspaces' => WorkspaceScreen(model: model),
  'review-timesheet' => ReviewTimesheetScreen(
    repository: TimesheetRepository(model.auth.api),
    workspace: model.workspace!,
    id: 9,
    canReview: true,
  ),
  'account' => AccountScreen(model: model),
  _ => throw ArgumentError(name),
};
