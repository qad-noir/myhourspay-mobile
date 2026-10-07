import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/features/hours/hours_screen.dart';
import 'package:myhourspay/features/hours/models.dart';
import 'package:myhourspay/features/hours/monthly_overview_view.dart';
import 'package:myhourspay/features/hours/overtime_preferences.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/hours/workspace_settings_screen.dart';
import 'package:myhourspay/features/timesheets/timesheet_repository.dart';
import 'package:myhourspay/shared/overtime_summary.dart';
import 'package:myhourspay/shared/widgets.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'support/fixtures.dart';
import 'support/monthly_fixtures.dart';

const version =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
Json overtimeWorkspace({
  String basis = 'daily',
  bool manage = true,
  bool writable = true,
}) => {
  ...workspace,
  'overtime_basis': basis,
  'contracted_daily_minutes': 480,
  'settings_version': version,
  'can_manage_settings': manage,
  'writable': writable,
};
Json overtimePage({
  String basis = 'daily',
  int daily = 120,
  int weekly = 0,
  int last = 1,
}) {
  final records = [
    for (var i = 0; i < 5; i++)
      {
        ...entry(id: i + 1, date: '2026-09-${28 + i}'),
        'work_date': dateKey(DateTime(2026, 9, 28 + i)),
        'net_minutes': i == 0 ? 600 : 420,
        'end_time': i == 0 ? '19:30' : '16:30',
        'daily_overtime_minutes': i == 0 ? 120 : 0,
      },
  ];
  return {
    ...hoursPage(records),
    'meta': {'current_page': 1, 'last_page': last, 'per_page': 100, 'total': 5},
    'summary': {
      'total_minutes': 2280,
      'overtime_basis': basis,
      'contracted_daily_minutes': 480,
      'daily_overtime_minutes': daily,
      'weekly_overtime_minutes': weekly,
      'overtime_minutes': basis == 'daily' ? daily : weekly,
      'weeks': [
        {
          'start': '2026-09-28',
          'minutes': 2280,
          'target_minutes': 2400,
          'variance_minutes': -120,
          'daily_overtime_minutes': daily,
          'weekly_overtime_minutes': weekly,
          'overtime_minutes': basis == 'daily' ? daily : weekly,
        },
      ],
    },
  };
}

Widget settingsApp(dynamic model) => MaterialApp(
  theme: mhpTheme(),
  home: WorkspaceSettingsScreen(model: model),
);
Finder field(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  ),
  matching: find.byType(TextFormField),
);

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    for (final entry in {
      'Manrope': 'assets/fonts/Manrope.ttf',
      'DM Sans': 'assets/fonts/DMSans.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });
  test('typed overtime preserves alternatives, negative variance and opaque versions', () {
    final daily = HoursPage.fromJson(overtimePage());
    final weekly = HoursPage.fromJson(overtimePage(basis: 'weekly'));
    expect(daily.totalMinutes, 2280);
    expect(daily.overtimeMinutes, 120);
    expect(weekly.overtimeMinutes, 0);
    expect(daily.overtime.dailyMinutes, 120);
    expect(daily.overtime.weeklyMinutes, 0);
    expect(daily.weeks.single.variance, -120);
    expect(
      WeeklyBreakdownRow(week: daily.weeks.single, basis: 'daily').status,
      '2h below target',
    );
    expect(daily.entries.first.version, weekly.entries.first.version);
    expect(Workspace.fromJson(workspace).overtimeBasis, 'weekly');
    expect(Workspace.fromJson(workspace).contractedDailyMinutes, isNull);
    expect(Workspace.fromJson(workspace).settingsSupported, isFalse);
    expect(
      Workspace.fromJson({...overtimeWorkspace(), 'settings_version': ''})
          .settingsSupported,
      isFalse,
    );
  });
  test(
    'daily contract uses whole minutes and never switches selection by itself',
    () {
      expect(dailyContractMinutes('7', '30'), 450);
      expect(dailyContractMinutes('8', ''), 480);
      expect(dailyContractMinutes('0', '1'), 1);
      expect(dailyContractMinutes('24', '0'), 1440);
      expect(dailyContractMinutes('24', '1'), isNull);
      expect(dailyContractMinutes('7.5', '0'), isNull);
      expect(dailyContractMinutes('', ''), isNull);
      expect(
        Workspace.fromJson(overtimeWorkspace(basis: 'weekly')).overtimeBasis,
        'weekly',
      );
      final nulls = OvertimeTotals.fromJson({
        'overtime_minutes': 0,
        'daily_overtime_minutes': null,
      });
      expect(nulls.dailyMinutes, isNull);
    },
  );
  test('settings retries keep exact JSON, version and key; edited input gets a new key', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      ApiEnvironment.parse(
        'development',
        'http://localhost:8000/api/v1/mobile',
      ),
      transport: MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) throw http.ClientException('offline');
        return response({'data': overtimeWorkspace()});
      }),
    )..token = 'test-bearer';
    addTearDown(api.close);
    final repo = HoursRepository(api), mutation = MutationKey();
    final body = {'settings_version': version, 'contracted_daily_minutes': 450};
    await expectLater(
      repo.updateSettings(1, body, mutation),
      throwsA(isA<ApiFailure>()),
    );
    await repo.updateSettings(1, body, mutation);
    await repo.updateSettings(1, {
      ...body,
      'overtime_basis': 'daily',
    }, mutation);
    expect(requests[0].body, requests[1].body);
    expect(
      requests[0].headers['idempotency-key'],
      requests[1].headers['idempotency-key'],
    );
    expect(
      requests[2].headers['idempotency-key'],
      isNot(requests[1].headers['idempotency-key']),
    );
    expect(requests[1].headers['authorization'], 'Bearer test-bearer');
    expect(requests[1].headers['accept'], 'application/json');
    expect(requests[1].headers['content-type'], 'application/json');
    expect(jsonDecode(requests[1].body), body);
  });
  test('pagination never adds repeated range summaries', () async {
    final api = ApiClient(
      ApiEnvironment.parse(
        'development',
        'http://localhost:8000/api/v1/mobile',
      ),
      transport: MockClient((request) async => response(overtimePage(last: 2))),
    );
    addTearDown(api.close);
    final page = await HoursRepository(api)
        .range(1, DateTime(2026, 9, 28), DateTime(2026, 10, 4));
    expect(page.overtime.dailyMinutes, 120);
    expect(page.overtimeMinutes, 120);
    expect(page.totalMinutes, 2280);
  });
  test('monthly daily total excludes expanded-week excess', () async {
    var basis = 'daily';
    final model = monthModel(
      client: MockClient(
        (request) async => response(
          overtimePage(
            basis: basis,
            daily: request.url.queryParameters['start'] == '2026-09-01'
                ? 120
                : 360,
            weekly: 240,
          ),
        ),
      ),
    );
    addTearDown(model.dispose);
    model.workspace = Workspace.fromJson(overtimeWorkspace());
    await loadFixtureMonth(model);
    expect(model.monthly.dailyOvertimeMinutes, 120);
    expect(model.monthly.weeklyOvertimeMinutes, 240);
    expect(model.monthly.overtimeMinutes, 120);
    basis = 'weekly';
    model.monthly.invalidateSettings(
      model.account!.id,
      Workspace.fromJson(overtimeWorkspace(basis: basis)),
    );
    await model.monthly.refresh();
    expect(model.monthly.overtimeMinutes, 240);
    expect(model.monthly.dailyOvertimeMinutes, 120);
  });
  testWidgets('nullable daily comparison is not presented as zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: mhpTheme(),
        home: Scaffold(
          body: OvertimeSummary(
            totals: OvertimeTotals.fromJson({
              'overtime_minutes': 0,
              'weekly_overtime_minutes': 0,
              'daily_overtime_minutes': null,
            }),
          ),
        ),
      ),
    );
    expect(find.text('Not configured'), findsOneWidget);
    expect(find.text('Weekly overtime'), findsOneWidget);
  });
  testWidgets(
    'stale settings block resubmission until newer server values reviewed',
    (tester) async {
      var patches = 0;
      final model = monthModel(
        client: MockClient((request) async {
          if (request.method == 'PATCH') {
            patches++;
            return response({
              'code': 'workspace_settings_changed',
              'message': 'Changed',
            }, 409);
          }
          if (request.url.path.endsWith('/workspaces')) {
            return response({
              'data': [
                {
                  ...overtimeWorkspace(basis: 'weekly'),
                  'weekly_target_minutes': 2100,
                  'settings_version': 'b' * 64,
                },
              ],
            });
          }
          return response(overtimePage());
        }),
      );
      addTearDown(model.dispose);
      model.auth.api.token = 'test-bearer';
      model.workspace = Workspace.fromJson(overtimeWorkspace());
      await tester.pumpWidget(settingsApp(model));
      await tester.enterText(field('Weekly contracted hours'), '39');
      await tester.ensureVisible(find.text('Save settings'));
      await tester.tap(find.text('Save settings'));
      await tester.pumpAndSettle();
      expect(patches, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save settings'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Reload server settings'));
      await tester.tap(find.text('Reload server settings'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(field('Weekly contracted hours'))
            .controller!
            .text,
        '35.0',
      );
      expect(model.workspace!.settingsVersion, 'b' * 64);
      expect(patches, 1);
    },
  );
  for (final scenario in ['old backend', 'member', 'read-only']) {
    testWidgets('$scenario cannot save workspace settings', (tester) async {
      final model = monthModel();
      addTearDown(model.dispose);
      model.workspace = Workspace.fromJson(
        scenario == 'old backend'
            ? workspace
            : overtimeWorkspace(
                manage: scenario != 'member',
                writable: scenario != 'read-only',
              ),
      );
      await tester.pumpWidget(settingsApp(model));
      expect(find.text('Save settings'), findsNothing);
      expect(
        tester.widget<TextFormField>(field('Weekly contracted hours')).enabled,
        isFalse,
      );
    });
  }
  testWidgets(
    'approved sheet displays current server overtime without changing lock/version',
    (tester) async {
      final sheet = Timesheet.fromJson({
        'id': 1,
        'status': 'approved',
        'week_start': '2026-09-28',
        'version': version,
        'total_minutes': 2280,
        'overtime_basis': 'daily',
        'daily_overtime_minutes': 120,
        'weekly_overtime_minutes': 0,
        'overtime_minutes': 120,
        'contracted_daily_minutes': 480,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OvertimeSummary(totals: sheet.overtime)),
        ),
      );
      expect(find.text('Daily overtime'), findsOneWidget);
      expect(find.text('2h 0m'), findsNWidgets(2));
      expect(sheet.status, 'approved');
      expect(sheet.version, version);
    },
  );

  if (const bool.fromEnvironment('MHP_CAPTURE')) {
    for (final mode in ['settings', 'month', 'week']) {
      testWidgets('capture overtime $mode at Android phone size', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final today = workspaceToday('Europe/London');
        final start = weekStart(today);
        final previewPage = overtimePage();
        previewPage['data'] = [
          for (var i = 0; i < 5; i++)
            {
              ...(previewPage['data'][i] as Json),
              'work_date': dateKey(
                DateTime(start.year, start.month, start.day + i),
              ),
            },
        ];
        final model = monthModel(
          client: MockClient((_) async => response(previewPage)),
        );
        addTearDown(model.dispose);
        model.workspace = Workspace.fromJson(overtimeWorkspace());
        model.auth.api.token = 'fixture-bearer';
        model.overviewMonthly = mode != 'week';
        await model.reload();
        await loadFixtureMonth(model, month: DateTime(today.year, today.month));
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: mhpTheme(),
              home: mode == 'settings'
                  ? WorkspaceSettingsScreen(model: model)
                  : ListenableBuilder(
                      listenable: model,
                      builder: (_, _) => HoursScreen(model: model),
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await precacheImage(
            const AssetImage('assets/brand/brand-mark.png'),
            tester.element(find.byType(Scaffold).first),
          );
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('docs/overtime-review')
            ..createSync(recursive: true);
          File('${directory.path}/$mode-390.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
