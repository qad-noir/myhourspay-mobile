import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/core/json_fields.dart';
import 'package:myhourspay/core/session_store.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/auth/auth_screens.dart';
import 'package:myhourspay/features/hours/models.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/hours/hours_screen.dart';
import 'package:myhourspay/features/session/session_model.dart';
import 'package:myhourspay/shared/widgets.dart';
import 'package:myhourspay/main.dart';

import 'support/fixtures.dart';

SessionModel modelFor(
  MockClient client, {
  Duration timeout = const Duration(seconds: 20),
}) {
  final api = ApiClient(
    ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
    transport: client,
    timeout: timeout,
  );
  return SessionModel(
    AuthRepository(api),
    HoursRepository(api),
    MemorySessionStore(),
  );
}

void main() {
  setUpAll(tz.initializeTimeZones);
  test('production MySQL foreign-key strings support saved entries and populated weeks', () async {
    final record = {...entry(), 'workspace_id': '1', 'project_id': '4'};
    final model = modelFor(
      MockClient(
        (r) async => response(
          r.method == 'GET' ? hoursPage([record]) : {'data': record},
        ),
      ),
    );
    model.auth.api.token = 'test-token';
    final saved = await model.hours.save(
      1,
      HoursDraft(
        date: DateTime(2026, 9, 28),
        start: '09:00',
        end: '17:00',
        breakMinutes: 30,
        paidBreak: false,
        notes: '',
      ),
      MutationKey(),
    );
    expect(saved.workspaceId, 1);
    expect(saved.projectId, 4);
    await model.selectWorkspace(Workspace.fromJson(workspace));
    expect(model.failure, isNull);
    expect(model.page!.totalMinutes, 450);
    expect(model.page!.entries.single.id, saved.id);
    await model.reload();
    expect(model.page!.entries.length, 1);
    model.dispose();
  });
  test('invalid resource IDs never become rounded or default IDs', () {
    for (final invalid in [null, '', '1.2', 'oops', -1, 0, 1.5, true]) {
      expect(() => jsonId(invalid), throwsFormatException);
    }
    expect(nullableJsonId(null), isNull);
  });
  test('confirmed creation survives a failed follow-up refresh', () async {
    var writes = 0;
    final model = modelFor(
      MockClient((r) async {
        if (r.method == 'POST') {
          writes++;
          return response({'data': workspace}, 201);
        }
        return response({}, 503);
      }),
    );
    model.phase = SessionPhase.authenticated;
    expect(await model.createWorkspace({}), true);
    expect(writes, 1);
    expect(model.workspaces.single.id, 1);
    expect(model.notice, startsWith('Workspace created.'));
    model.dispose();
  });
  testWidgets(
    'first workspace confirmation survives the onboarding navigation change',
    (tester) async {
      var created = false;
      final model = modelFor(
        MockClient((r) async {
          if (r.url.path.endsWith('/auth/providers')) {
            return response({'data': {}});
          }
          if (r.method == 'POST') {
            created = true;
            return response({'data': workspace}, 201);
          }
          if (r.url.path.endsWith('/me')) {
            return response({
              'data': {...user, 'onboarding_required': !created},
            });
          }
          return response({
            'data': created ? [workspace] : [],
          });
        }),
      );
      (model.store as MemorySessionStore).value = StoredSession(
        'test-token',
        DateTime.now().add(const Duration(days: 1)),
      );
      await tester.pumpWidget(MhpApp(model: model));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create workspace'));
      await tester.tap(find.text('Create workspace'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Workspace name'),
        'Test workspace',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Your position'),
        'Developer',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Create workspace'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create workspace'));
      await tester.pumpAndSettle();
      expect(model.phase, SessionPhase.authenticated);
      expect(find.text('Choose your workspace'), findsOneWidget);
      expect(find.text('Workspace created successfully.'), findsOneWidget);
      expect(find.text('Test workspace'), findsOneWidget);
    },
  );
  testWidgets(
    'workspace target is hours, bottom button validates and converts 37.5 hours to minutes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Json? posted;
      final model = modelFor(
        MockClient((r) async {
          if (r.method == 'POST') {
            posted = jsonDecode(r.body) as Json;
            return response({'data': workspace}, 201);
          }
          if (r.url.path.endsWith('/me')) return response({'data': user});
          return response({
            'data': [workspace],
          });
        }),
      )..phase = SessionPhase.authenticated;
      await tester.pumpWidget(
        MaterialApp(
          theme: mhpTheme(),
          home: CreateWorkspaceScreen(model: model),
        ),
      );
      expect(
        find.widgetWithText(TextFormField, 'Weekly target (hours)'),
        findsOneWidget,
      );
      expect(tester.getTopLeft(find.byType(FilledButton)).dy, greaterThan(700));
      await tester.tap(find.widgetWithText(FilledButton, 'Create workspace'));
      await tester.pump();
      expect(posted, isNull);
      expect(find.text('Enter 3–100 characters.'), findsNWidgets(2));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Workspace name'),
        'Test workspace',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Your position'),
        'Developer',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Weekly target (hours)'),
        '37.5',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create workspace'));
      await tester.pumpAndSettle();
      expect(posted!['weekly_target_minutes'], 2250);
      expect(model.notice, 'Workspace created successfully.');
      model.dispose();
    },
  );
  for (final timedOut in [false, true]) {
    testWidgets(
      'password reset shows ${timedOut ? 'timeout and retry' : 'progress and confirmation'}',
      (tester) async {
        final pending = Completer<void>();
        final model = modelFor(
          MockClient((r) async {
            await pending.future;
            return response({'message': 'generic'});
          }),
          timeout: timedOut
              ? const Duration(milliseconds: 20)
              : const Duration(seconds: 20),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: mhpTheme(),
            home: Scaffold(
              body: ForgotPasswordDialog(
                model: model,
                initialEmail: 'test@example.test',
              ),
            ),
          ),
        );
        await tester.tap(find.text('Send reset link'));
        await tester.pump();
        expect(find.text('Requesting a reset link…'), findsOneWidget);
        if (timedOut) {
          await tester.pump(const Duration(milliseconds: 30));
          await tester.pump();
          expect(find.textContaining('not confirmed'), findsOneWidget);
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNotNull,
          );
        } else {
          pending.complete();
          await tester.pumpAndSettle();
          expect(find.textContaining('If the account exists'), findsOneWidget);
          expect(find.text('Done'), findsOneWidget);
          expect(find.text('Send reset link'), findsNothing);
        }
        if (!pending.isCompleted) pending.complete();
        model.dispose();
      },
    );
  }
}
