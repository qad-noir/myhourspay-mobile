import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/features/hours/chart_allocation.dart';
import 'package:myhourspay/features/hours/hours_report_screen.dart';
import 'package:myhourspay/features/hours/models.dart';
import 'package:myhourspay/features/hours/monthly_overview_view.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/shared/hours_widgets.dart';
import 'package:myhourspay/shared/widgets.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'support/fixtures.dart';
import 'support/monthly_fixtures.dart';

// Dates/times from the backend regression, excluding all personal data.
List<Json> reportRecords() {
  final ends = {
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
  var id = 0;
  return [
    for (final value in ends.entries)
      {
        ...entry(id: ++id, date: value.key),
        'start_time': '06:15',
        'end_time': value.value,
        'break_minutes': 30,
        'break_type': 'unpaid',
        'net_minutes': HoursDraft.clock(value.value)! - 375 - 30,
        'daily_overtime_minutes':
            (HoursDraft.clock(value.value)! - 375 - 30 - 480).clamp(0, 1440),
      },
  ];
}

void main() {
  registerReportCaptures();
  testWidgets(
    'calendar shows logged hours only and keeps overtime dates compact',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthCalendar(
              month: DateTime(2026, 10),
              today: DateTime(2026, 10, 12),
              selected: DateTime(2026, 10, 6),
              available: true,
              entries: [
                HoursEntry.fromJson({
                  ...entry(date: '2026-10-06'),
                  'net_minutes': 510,
                  'daily_overtime_minutes': 30,
                }),
                HoursEntry.fromJson({
                  ...entry(date: '2026-10-07'),
                  'net_minutes': 510,
                  'daily_overtime_minutes': 0,
                }),
              ],
            ),
          ),
        ),
      );
      final cell = find.byKey(const ValueKey('month-day-2026-10-06'));
      expect(
        find.descendant(of: cell, matching: find.text('8h 30m')),
        findsOneWidget,
      );
      expect(find.textContaining('daily'), findsNothing);
      final container = find
          .descendant(of: cell, matching: find.byType(Container))
          .first;
      final ordinary = find
          .descendant(
            of: find.byKey(const ValueKey('month-day-2026-10-07')),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(container).height, tester.getSize(ordinary).height);
      expect(tester.takeException(), isNull);
    },
  );
  setUpAll(() async {
    tz.initializeTimeZones();
    for (final font in {
      'Manrope': 'assets/fonts/Manrope.ttf',
      'DM Sans': 'assets/fonts/DMSans.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  testWidgets(
    'report loads fresh preferences, saves selection and refetches server totals',
    (tester) async {
      var basis = 'weekly';
      Json? saved;
      final model = monthModel(
        client: MockClient((request) async {
          final workspaceData = {
            ...workspace,
            'overtime_basis': basis,
            'contracted_daily_minutes': 480,
            'settings_version': (basis == 'weekly' ? 'b' : 'c') * 64,
            'can_manage_settings': true,
          };
          if (request.method == 'PATCH') {
            saved = jsonDecode(request.body) as Json;
            basis = saved!['overtime_basis'] as String;
            return response({
              'data': {
                ...workspaceData,
                'overtime_basis': basis,
                'settings_version': 'c' * 64,
              },
            });
          }
          if (request.url.path.endsWith('/workspaces')) {
            return response({
              'data': [workspaceData],
            });
          }
          final data = rangeFixture(
            reportRecords(),
            DateTime(2026, 9, 1),
            DateTime(2026, 10, 31),
          );
          data['summary'] = <String, dynamic>{
            ...(data['summary'] as Json),
            'overtime_basis': basis,
            'contracted_daily_minutes': 480,
            'daily_overtime_minutes': 1995,
            'weekly_overtime_minutes': 1845,
            'overtime_minutes': basis == 'daily' ? 1995 : 1845,
          };
          return response(data);
        }),
      );
      addTearDown(model.dispose);
      model.auth.api.token = 'fixture-bearer';
      model.workspace = Workspace.fromJson({
        ...workspace,
        'overtime_basis': 'weekly',
        'contracted_daily_minutes': null,
        'settings_version': 'a' * 64,
        'can_manage_settings': true,
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: mhpTheme(),
          home: HoursReportScreen(model: model, start: DateTime(2026, 9, 1)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Weekly overtime'), findsOneWidget);
      await tester.tap(find.text('Change overtime calculation'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is TextField && widget.controller?.text == '8',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Daily'));
      await tester.ensureVisible(find.text('Save settings'));
      await tester.tap(find.text('Save settings'));
      await tester.pumpAndSettle();
      expect(saved, {'settings_version': 'b' * 64, 'overtime_basis': 'daily'});
      expect(find.text('Daily overtime'), findsOneWidget);
      expect(find.text('33h 15m'), findsWidgets);
      expect(model.workspace!.overtimeBasis, 'daily');
      expect(tester.takeException(), isNull);
    },
  );
  test(
    '27-entry report reconciles 249:15 net, 33:15 daily and 30:45 weekly',
    () async {
      final records = reportRecords();
      final versions = records.map((record) => record['version']).toList();
      final api = ApiClient(
        ApiEnvironment.parse(
          'development',
          'http://fixture.invalid/api/v1/mobile',
        ),
        transport: MockClient((request) async {
          final page = rangeFixture(
            records,
            DateTime(2026, 9, 1),
            DateTime(2026, 10, 31),
            page: int.parse(request.url.queryParameters['page'] ?? '1'),
            pageSize: 7,
          );
          final summary = <String, dynamic>{...(page['summary'] as Json)};
          page['summary'] = summary;
          summary.addAll({
            'overtime_basis': 'daily',
            'contracted_daily_minutes': 480,
            'daily_overtime_minutes': 1995,
            'weekly_overtime_minutes': 1845,
            'overtime_minutes': 1995,
          });
          (summary['weeks'] as List).first['partial'] = true;
          return response(page);
        }),
      );
      addTearDown(api.close);
      final page = await HoursRepository(api)
          .range(7, DateTime(2026, 9, 1), DateTime(2026, 10, 31));
      expect(page.entries.length, 27);
      expect(page.totalMinutes, 14955);
      expect(page.overtimeMinutes, 1995);
      expect(page.overtime.weeklyMinutes, 1845);
      expect(page.weeks.first.partial, isTrue);
      final daily = page.entries.fold<int>(
        0,
        (sum, entry) => sum + (entry.netMinutes - 480).clamp(0, 1440),
      );
      final weeks = <String, int>{};
      for (final entry in page.entries) {
        final key = dateKey(weekStart(entry.date));
        weeks[key] = (weeks[key] ?? 0) + entry.netMinutes;
      }
      expect(daily, 1995);
      expect(
        weeks.values.fold<int>(
          0,
          (sum, total) => sum + (total - 2400).clamp(0, 100000),
        ),
        1845,
      );
      expect(page.entries.map((entry) => entry.version).toList(), versions);
    },
  );

  test('daily chart is independent of Weekly summary; returned daily values are authoritative', () {
    final monday = DateTime(2026, 10, 5);
    final entries = [
      for (var i = 0; i < 5; i++)
        HoursEntry.fromJson({
          ...entry(
            id: i + 1,
            date: dateKey(monday.add(Duration(days: i))),
          ),
          'net_minutes': i == 0 ? 600 : 420,
          'daily_overtime_minutes': i == 0 ? 120 : 0,
        }),
    ];
    final daily = allocateDailyWeek(
      week: monday,
      entries: entries,
      dailyContract: 480,
    );
    expect(daily.map((day) => day.overtime).toList(), [120, 0, 0, 0, 0, 0, 0]);
    final weeklySummary = OvertimeTotals.fromJson({
      'overtime_basis': 'weekly',
      'overtime_minutes': 0,
      'daily_overtime_minutes': 120,
      'weekly_overtime_minutes': 0,
    });
    expect(weeklySummary.selectedMinutes, 0);
    expect(daily.fold<int>(0, (sum, day) => sum + day.overtime!), 120);
    final missing = allocateDailyWeek(week: monday, entries: entries);
    expect(missing.every((day) => day.overtime == null), isTrue);
    final serverValue = HoursEntry.fromJson({
      ...entry(date: dateKey(monday)),
      'net_minutes': 600,
      'daily_overtime_minutes': 90,
    });
    expect(
      allocateDailyWeek(
        week: monday,
        entries: [serverValue],
        dailyContract: 480,
      ).first.overtime,
      90,
    );
  });
  testWidgets(
    '12h stacked chart has legend, accessible totals and no fake empty bars',
    (tester) async {
      final date = DateTime(2026, 10, 5);
      final entries = [
        HoursEntry.fromJson({
          ...entry(date: dateKey(date)),
          'net_minutes': 720,
        }),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: mhpTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: WeekChart(
                week: date,
                entries: entries,

                dailyContract: 480,
              ),
            ),
          ),
        ),
      );
      expect(find.text('12h'), findsOneWidget);
      expect(find.text('Regular hours'), findsOneWidget);
      expect(find.text('Daily overtime'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Tooltip &&
              widget.message == '8h 0m regular, 4h 0m daily overtime',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      final green = find.byWidgetPredicate(
        (widget) =>
            widget is Container && widget.color == const Color(0xff168456),
      );
      expect(green, findsOneWidget);
      final orange = find.byWidgetPredicate(
        (widget) =>
            widget is Container && widget.color == const Color(0xffff6b35),
      );
      expect(orange, findsOneWidget);
      expect(
        tester.getSize(green).height + tester.getSize(orange).height,
        closeTo(84, .01),
      );
    },
  );

  testWidgets(
    'partial week explains excluded dates rather than incomplete entries',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyBreakdownRow(
              week: HoursWeek(
                start: DateTime(2026, 8, 31),
                minutes: 2200,
                targetMinutes: 2400,
                partial: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Partial week'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Tooltip && widget.message == 'The selected dates exclude part of this week. Daily overtime uses only the selected dates.',
        ),
        findsOneWidget,
      );
    },
  );
}

void registerReportCaptures() {
  if (!const bool.fromEnvironment('MHP_CAPTURE')) return;
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('render report ${platform.name} at phone size', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = monthModel(
        client: MockClient((_) async {
          final data = rangeFixture(
            reportRecords(),
            DateTime(2026, 9, 1),
            DateTime(2026, 10, 31),
          );
          data['summary'] = <String, dynamic>{
            ...(data['summary'] as Json),
            'overtime_basis': 'daily',
            'contracted_daily_minutes': 480,
            'daily_overtime_minutes': 1995,
            'weekly_overtime_minutes': 1845,
            'overtime_minutes': 1995,
          };
          final weeks = data['summary']['weeks'] as List;
          weeks.first['partial'] = true;
          return response(data);
        }),
      );
      addTearDown(model.dispose);
      model.auth.api.token = 'fixture-bearer';
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: mhpTheme().copyWith(platform: platform),
            home: HoursReportScreen(
              model: model,
              start: DateTime(2026, 9, 1),
              end: DateTime(2026, 10, 31),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('docs/overtime-review').createSync(recursive: true);
        File('docs/overtime-review/report-${platform.name}-390.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
