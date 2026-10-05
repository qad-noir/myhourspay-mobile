import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/core/session_store.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/hours/hours_screen.dart';
import 'package:myhourspay/features/hours/models.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/session/session_model.dart';
import 'package:myhourspay/shared/hours_widgets.dart';
import 'package:myhourspay/shared/widgets.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'support/fixtures.dart';

SessionModel makeModel(SessionStore store, {bool failHistory = false}) {
  final api = ApiClient(
    ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
    transport: MockClient((r) async {
      if (r.url.path.endsWith('/auth/providers')) return response({'data': {}});
      if (r.url.path.endsWith('/me')) return response({'data': user});
      if (r.url.path.endsWith('/workspaces')) {
        return response({
          'data': [
            workspace,
            {...workspace, 'id': 2, 'name': 'Second workspace'},
          ],
        });
      }
      if (r.method == 'DELETE') return response({}, 204);
      final start = r.url.queryParameters['start']!;
      final current = dateKey(weekStart(workspaceToday('Europe/London')));
      if (failHistory && start != current) {
        return response({'message': 'Unavailable'}, 503);
      }
      return response(
        hoursPage(
          start == current
              ? [entry(date: start)]
              : [entry(date: start), entry(id: 2, date: start)],
        ),
      );
    }),
  );
  return SessionModel(AuthRepository(api), HoursRepository(api), store);
}

StoredSession saved({int? workspaceId}) => StoredSession(
  'test-token',
  DateTime.now().add(const Duration(days: 1)),
  workspaceId: workspaceId,
);

class DelayedStore extends MemorySessionStore {
  final started = Completer<void>(), finish = Completer<void>();
  @override
  Future<void> write(StoredSession value) async {
    started.complete();
    await finish.future;
    await super.write(value);
  }
}

void main() {
  setUpAll(tz.initializeTimeZones);
  test(
    'secure session preference round trips and legacy sessions remain valid',
    () {
      expect(
        StoredSession.decode(saved(workspaceId: 2).encode()).workspaceId,
        2,
      );
      final legacy = jsonEncode({
        'access_token': 'test-token',
        'expires_at': DateTime.now().toUtc().toIso8601String(),
      });
      expect(StoredSession.decode(legacy).workspaceId, isNull);
      expect(
        StoredSession.decode(
          jsonEncode({...jsonDecode(legacy), 'workspace_id': -1}),
        ).workspaceId,
        isNull,
      );
    },
  );
  test('restart reopens last authorized workspace and logout clears the preference', () async {
    final store = MemorySessionStore()..value = saved();
    final first = makeModel(store);
    await first.restore();
    await first.selectWorkspace(first.workspaces.last);
    expect(store.value!.workspaceId, 2);
    first.dispose();
    final restarted = makeModel(store);
    addTearDown(restarted.dispose);
    await restarted.restore();
    expect(restarted.workspace!.id, 2);
    expect(restarted.page, isNotNull);
    await restarted.logout();
    expect(store.value, isNull);
  });
  test('removed remembered workspace opens chooser without unauthorized hours request', () async {
    final store = MemorySessionStore()..value = saved(workspaceId: 999);
    final model = makeModel(store);
    addTearDown(model.dispose);
    await model.restore();
    expect(model.phase, SessionPhase.authenticated);
    expect(model.workspace, isNull);
    expect(model.selectedWorkspaceId, isNull);
  });
  testWidgets(
    'Hours retains historical week while Overview always shows current week',
    (tester) async {
      final model = makeModel(
        MemorySessionStore()..value = saved(workspaceId: 2),
      );
      model.overviewMonthly = false;
      await model.restore();
      final current = model.overviewWeek;
      final historical = current.subtract(const Duration(days: 14));
      await model.selectWeek(historical);
      expect(model.page!.totalMinutes, 900);
      expect(model.overviewData!.totalMinutes, 450);
      await tester.pumpWidget(
        MaterialApp(
          theme: mhpTheme(),
          home: ListenableBuilder(
            listenable: model,
            builder: (_, _) => HoursScreen(model: model, initialTab: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(weekLabel(historical)), findsOneWidget);
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      expect(find.text(weekLabel(current)), findsOneWidget);
      expect(find.text('7h 30m'), findsWidgets);
      expect(model.week, historical);
      await tester.tap(find.text('Hours'));
      await tester.pumpAndSettle();
      expect(find.text(weekLabel(historical)), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    },
  );
  test('historical error does not hide current Overview totals', () async {
    final model = makeModel(
      MemorySessionStore()..value = saved(workspaceId: 2),
      failHistory: true,
    );
    addTearDown(model.dispose);
    await model.restore();
    await model.moveWeek(-14);
    expect(model.failure, isNotNull);
    expect(model.overviewFailure, isNull);
    expect(model.overviewData!.totalMinutes, 450);
  });
  test('late preference write cannot recreate session after logout', () async {
    final store = DelayedStore()..value = saved();
    final model = makeModel(store);
    addTearDown(model.dispose);
    await model.restore();
    final selection = model.selectWorkspace(model.workspaces.last);
    await store.started.future;
    final logout = model.logout();
    store.finish.complete();
    await Future.wait([selection, logout]);
    expect(store.value, isNull);
    expect(model.workspace, isNull);
    expect(model.phase, SessionPhase.signedOut);
  });
}
