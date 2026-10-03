import 'dart:async';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/account/account_screen.dart';
import 'package:myhourspay/features/hours/hours_screen.dart';
import 'package:myhourspay/features/hours/edit_hours_screen.dart';
import 'package:myhourspay/features/hours/models.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/session/session_model.dart';
import 'package:myhourspay/shared/widgets.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'support/fixtures.dart';

SessionModel createModel(MockClient transport) {
  final api = ApiClient(
    ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
    transport: transport,
  );
  final model = SessionModel(
    AuthRepository(api),
    HoursRepository(api),
    MemorySessionStore(),
  );
  model.auth.api.token = 'test-token';
  model.account = Account.fromJson(user);
  model.workspace = Workspace.fromJson(workspace);
  model.week = DateTime(2026, 9, 28);
  model.page = HoursPage.fromJson(
    hoursPage([entry(), entry(id: 2, date: '2026-09-30')]),
  );
  return model;
}

Widget shell(Widget child) => MaterialApp(
  theme: mhpTheme(),
  home: Navigator(
    onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => child),
  ),
);
void main() {
  setUpAll(tz.initializeTimeZones);
  testWidgets(
    'revoke cancel closes root dialog; confirmed DELETE removes session',
    (tester) async {
      var deletes = 0;
      final model = createModel(
        MockClient((r) async {
          if (r.method == 'DELETE') {
            deletes++;
            return response({}, 204);
          }
          return response({
            'data': [
              {
                'id': 4,
                'device_name': 'Other phone',
                'current': false,
                'last_used_at': null,
                'expires_at': null,
              },
            ],
          });
        }),
      );
      addTearDown(model.dispose);
      await tester.pumpWidget(shell(AccountScreen(model: model)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(deletes, 0);
      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(find.text('Other phone'), findsNothing);
      expect(find.text('Device revoked.'), findsOneWidget);
    },
  );
  testWidgets(
    'cached account sessions remain visible during background reload',
    (tester) async {
      final pending = Completer<List<DeviceSession>>();
      final model = createModel(
        MockClient((_) async {
          await pending.future;
          return response({'data': []});
        }),
      );
      model.deviceSessions = [
        DeviceSession.fromJson({
          'id': 4,
          'device_name': 'Cached phone',
          'current': false,
          'last_used_at': null,
          'expires_at': null,
        }),
      ];
      addTearDown(model.dispose);
      await tester.pumpWidget(shell(AccountScreen(model: model)));
      await tester.pump();
      expect(find.text('Cached phone'), findsOneWidget);
      expect(find.byType(LoadingCards), findsNothing);
      pending.complete([]);
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'overview newest date first; chart opens edit or add for tapped day',
    (tester) async {
      final model = createModel(
        MockClient((_) async => response(hoursPage([]))),
      );
      addTearDown(model.dispose);
      await tester.pumpWidget(shell(HoursScreen(model: model)));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('30 Sep')).dy,
        lessThan(tester.getTopLeft(find.text('28 Sep')).dy),
      );
      await tester.tap(find.text('Wed'));
      await tester.pumpAndSettle();
      expect(find.text('Update hours'), findsWidgets);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thu'));
      await tester.pumpAndSettle();
      expect(find.text('Thursday, 1 Oct'), findsOneWidget);
      expect(find.text('Save hours'), findsOneWidget);
    },
  );

  testWidgets(
    'calendar opens today and unchanged OK preserves a historical week',
    (tester) async {
      var reads = 0;
      final model = createModel(
        MockClient((request) async {
          reads++;
          return response(hoursPage([]));
        }),
      );
      final today = workspaceToday(model.workspace!.timezone);
      model.week = weekStart(DateTime(today.year, today.month - 2, 1));
      final previousWeek = model.week;
      final previousPage = model.page;
      addTearDown(model.dispose);
      await tester.pumpWidget(
        shell(
          ListenableBuilder(
            listenable: model,
            builder: (_, _) => HoursScreen(model: model, initialTab: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a date'));
      await tester.pumpAndSettle();
      final picker = tester.widget<CalendarDatePicker2>(
        find.byType(CalendarDatePicker2),
      );
      expect(picker.value, [today]);
      final monthReads = reads;
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(model.week, previousWeek);
      expect(model.page, same(previousPage));
      expect(reads, monthReads);
    },
  );
  test('selecting a different date in the displayed week skips reload and notifications', () async {
    var reads = 0, changes = 0;
    final model = createModel(
      MockClient((request) async {
        reads++;
        return response(hoursPage([]));
      }),
    );
    addTearDown(model.dispose);
    final page = model.page;
    model.addListener(() => changes++);
    await model.selectWeek(model.week.add(const Duration(days: 5)));
    expect(reads, 0);
    expect(changes, 0);
    expect(model.page, same(page));
    final next = model.week.add(const Duration(days: 7));
    await model.selectWeek(next);
    expect(reads, 1);
    expect(model.week, next);
  });
  testWidgets('calendar marks API dates and selection loads containing week', (
    tester,
  ) async {
    final requests = <String>[];
    final today = workspaceToday('Europe/London');
    final chosen = DateTime(today.year, today.month, today.day == 14 ? 15 : 14);
    final chosenWeek = weekStart(chosen);
    final model = createModel(
      MockClient((r) async {
        requests.add(r.url.query);
        return response(hoursPage([entry(id: 3, date: dateKey(chosen))]));
      }),
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      shell(
        ListenableBuilder(
          listenable: model,
          builder: (_, _) => HoursScreen(model: model, initialTab: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a date'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == '${dateKey(chosen)}, has an hours entry',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('${chosen.day}'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(model.week, chosenWeek);
    expect(
      requests.any(
        (q) =>
            q.contains('start=${dateKey(chosenWeek)}') &&
            q.contains(
              'end=${dateKey(chosenWeek.add(const Duration(days: 6)))}',
            ),
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'duplicate date explains editing instead of raw taken validation',
    (tester) async {
      final model = createModel(
        MockClient(
          (_) async => response({
            'code': 'validation_failed',
            'message': 'The work date has already been taken.',
            'errors': {
              'work_date': ['The work date has already been taken.'],
            },
          }, 422),
        ),
      );
      addTearDown(model.dispose);
      await tester.pumpWidget(
        shell(
          EditHoursScreen(model: model, initialDate: DateTime(2026, 9, 28)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save hours'));
      await tester.tap(find.text('Save hours'));
      await tester.pumpAndSettle();
      expect(
        find.text('This date already has an entry. Try editing it instead.'),
        findsWidgets,
      );
      expect(find.text('The work date has already been taken.'), findsNothing);
    },
  );
  test(
    'workspace selection persists across switch and clears on logout',
    () async {
      final model = createModel(
        MockClient(
          (r) async =>
              r.method == 'GET' ? response(hoursPage([])) : response({}, 204),
        ),
      );
      addTearDown(model.dispose);
      final second = Workspace.fromJson({...workspace, 'id': 2});
      await model.selectWorkspace(second);
      model.switchWorkspace();
      expect(model.selectedWorkspaceId, 2);
      await model.logout();
      expect(model.selectedWorkspaceId, isNull);
      expect(model.notice, isNull);
      expect(model.toast, 'Signed out.');
    },
  );
}
