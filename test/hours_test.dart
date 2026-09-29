import 'package:flutter_test/flutter_test.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/features/hours/models.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/session/session_model.dart';
import 'package:myhourspay/main.dart';
import 'package:flutter/material.dart';

HoursDraft draft(DateTime date, {String end = '17:00', int rest = 30}) =>
    HoursDraft(
      date: date,
      start: '09:00',
      end: end,
      breakMinutes: rest,
      paidBreak: false,
      notes: '',
    );
void main() {
  test('configuration fails closed and trusts only an exact origin', () {
    expect(ApiEnvironment.parse('demo', '').origin, isNull);
    expect(() => ApiEnvironment.parse('', ''), throwsFormatException);
    expect(
      () => ApiEnvironment.parse('production', 'http://example.test'),
      throwsFormatException,
    );
    expect(
      () => ApiEnvironment.parse(
        'development',
        'http://localhost',
        release: true,
      ),
      throwsFormatException,
    );
    final config = ApiEnvironment.parse('staging', 'https://example.test');
    expect(
      config.trusts(Uri.parse('https://example.test/api/v1/workspaces')),
      isTrue,
    );
    expect(
      config.trusts(Uri.parse('https://example.test.attacker.test')),
      isFalse,
    );
    expect(config.trusts(Uri.parse('https://example.test:8443')), isFalse);
  });
  test('same-day validation rejects overnight and excessive breaks', () {
    expect(
      draft(DateTime(2026, 9, 28), end: '08:00').validate(),
      contains('end'),
    );
    expect(
      draft(DateTime(2026, 9, 28), rest: 480).validate(),
      contains('break'),
    );
    expect(HoursDraft.clock('24:00'), isNull);
  });
  test(
    'calendar weeks cross year boundaries without elapsed-hour arithmetic',
    () {
      expect(dateKey(weekStart(DateTime(2027, 1, 1))), '2026-12-28');
    },
  );
  test('workspace switching and logout isolate demo records', () async {
    final model = SessionModel(DemoHoursRepository());
    await model.enterDemo();
    expect(model.phase, SessionPhase.authenticated);
    await model.selectWorkspace(model.workspaces.first);
    await model.add(draft(model.week));
    expect(model.entries.single.netMinutes, 450);
    await model.selectWorkspace(model.workspaces.last);
    expect(model.entries, isEmpty);
    model.logout();
    expect(model.phase, SessionPhase.signedOut);
    await model.enterDemo();
    await model.selectWorkspace(model.workspaces.first);
    expect(model.entries, isEmpty);
  });
  test('demo rejects duplicate dates and locked writes', () async {
    final repository = DemoHoursRepository();
    final entry = draft(DateTime(2026, 9, 28));
    await repository.add(1, entry);
    await expectLater(
      repository.add(1, entry),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', 'validation_failed'),
      ),
    );
    repository.locked.add(2);
    await expectLater(
      repository.add(2, entry),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', 'timesheet_locked'),
      ),
    );
  });
  testWidgets('demo vertical slice adds a day and displays total', (
    tester,
  ) async {
    await tester.pumpWidget(const MhpApp());
    await tester.tap(find.text('Explore demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My workspace'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Add hours'), 300);
    await tester.tap(find.text('Add hours'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Add to demo'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add to demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to demo'));
    await tester.pumpAndSettle();
    expect(find.text('Added to demo. Not saved to MHP.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Demo working hours'), -300);
    expect(find.text('7h 30m'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('welcome tolerates large text and narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const MhpApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
