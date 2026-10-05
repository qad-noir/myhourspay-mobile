import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/features/hours/models.dart';
import 'package:myhourspay/features/hours/monthly_overview_model.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'support/fixtures.dart';
import 'support/monthly_fixtures.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
  test(
    'illustrative month uses exact-month hours and expanded-week overtime',
    () async {
      final queries = <Uri>[];
      final model = monthModel(
        client: MockClient((request) async {
          queries.add(request.url);
          return fixtureForRequest(request, monthFixture());
        }),
      );
      addTearDown(model.dispose);
      await loadFixtureMonth(model);
      final totals = model.monthly.totals!;
      expect(totals.totalMinutes, 11040);
      expect(totals.workedDays, 22);
      expect(totals.averageMinutes, 502);
      expect(totals.breakCount, 22);
      expect(totals.paidMinutes, 0);
      expect(totals.unpaidMinutes, 660);
      expect(model.monthly.overtimeMinutes, 480);
      expect(model.monthly.weeks.map((week) => week.minutes), [
        2400,
        2640,
        2640,
        2400,
        2400,
      ]);
      expect(model.monthly.snapshot!.fullWeeks!.totalMinutes, 12480);
      expect(
        queries.map(
          (uri) =>
              '${uri.queryParameters['start']}/${uri.queryParameters['end']}',
        ),
        containsAll(['2026-09-01/2026-09-30', '2026-08-31/2026-10-04']),
      );
    },
  );
  test('boundary overtime includes outside-month days without adding them to month hours', () async {
    final records = [
      {...entry(date: '2026-08-31'), 'net_minutes': 720},
      for (var day = 1; day <= 4; day++)
        {...entry(id: day + 1, date: '2026-09-0$day'), 'net_minutes': 480},
    ];
    final model = monthModel(records: records);
    addTearDown(model.dispose);
    await loadFixtureMonth(model);
    expect(model.monthly.totals!.totalMinutes, 1920);
    expect(model.monthly.overtimeMinutes, 240);
    expect(model.monthly.snapshot!.calendar!.overtimeMinutes, 0);
    expect(model.monthly.weeks.length, 5);
    expect(model.monthly.weeks.last.minutes, 0);
    expect(model.monthly.weeks.last.targetMinutes, 2400);
  });
  test(
    'leap February and six-row months preserve Sunday-first local dates',
    () {
      expect(monthEnd(DateTime(2024, 2)), DateTime(2024, 2, 29));
      expect(monthCells(DateTime(2021, 2)).length, 35);
      final cells = monthCells(DateTime(2026, 5));
      expect(cells.length, 42);
      expect(cells.first, DateTime(2026, 4, 26));
      expect(cells.last, DateTime(2026, 6, 6));
    },
  );
  test('paid/unpaid breaks do not change backend net totals; worked dates are unique', () async {
    final records = [
      {
        ...entry(date: '2026-09-01'),
        'net_minutes': 480,
        'break_type': 'paid',
        'break_minutes': 20,
      },
      {
        ...entry(id: 2, date: '2026-09-02'),
        'net_minutes': 420,
        'break_minutes': 45,
      },
      {
        ...entry(id: 3, date: '2026-09-03'),
        'net_minutes': 60,
        'break_minutes': 0,
      },
    ];
    final model = monthModel(records: records, target: 1800);
    addTearDown(model.dispose);
    await loadFixtureMonth(model);
    final totals = model.monthly.totals!;
    expect(totals.totalMinutes, 960);
    expect(totals.workedDays, 3);
    expect(totals.averageMinutes, 320);
    expect(totals.breakCount, 2);
    expect(totals.paidMinutes, 20);
    expect(totals.unpaidMinutes, 45);
    expect(model.monthly.weeks.first.targetMinutes, 1800);
  });
  test(
    'empty month fills empty weeks with the actual target and zero average',
    () async {
      final model = monthModel(records: [], target: 2100);
      addTearDown(model.dispose);
      await loadFixtureMonth(model);
      expect(model.monthly.totals!.totalMinutes, 0);
      expect(model.monthly.totals!.averageMinutes, 0);
      expect(model.monthly.weeks.length, 5);
      expect(
        model.monthly.weeks.every(
          (week) => week.minutes == 0 && week.targetMinutes == 2100,
        ),
        true,
      );
    },
  );
  test(
    'pagination loads every entry but counts the range summary only once',
    () async {
      var requests = 0;
      final model = monthModel(
        client: MockClient((request) async {
          requests++;
          expect(request.url.queryParameters['per_page'], '100');
          return fixtureForRequest(request, monthFixture(), pageSize: 7);
        }),
      );
      addTearDown(model.dispose);
      await loadFixtureMonth(model);
      expect(requests, 8);
      expect(model.monthly.totals!.entries.length, 22);
      expect(model.monthly.totals!.totalMinutes, 11040);
      expect(model.monthly.overtimeMinutes, 480);
    },
  );
  test('workspace switch and sign-out discard late month responses and sensitive cache', () async {
    final held = <Completer<http.Response>>[];
    final model = monthModel(
      client: MockClient((request) {
        if (request.url.path.contains('/workspaces/1/')) {
          final pending = Completer<http.Response>();
          held.add(pending);
          return pending.future;
        }
        return Future.value(
          response(
            rangeFixture(
              [],
              DateTime.parse(request.url.queryParameters['start']!),
              DateTime.parse(request.url.queryParameters['end']!),
            ),
          ),
        );
      }),
    );
    addTearDown(model.dispose);
    model.monthly.bind(1, model.workspace!);
    final old = model.monthly.selectMonth(DateTime(2026, 9));
    await Future<void>.delayed(Duration.zero);
    model.monthly.bind(1, Workspace.fromJson({...workspace, 'id': 2}));
    await model.monthly.refresh();
    for (final pending in held) {
      pending.complete(
        response(
          rangeFixture(
            monthFixture(),
            DateTime(2026, 8, 31),
            DateTime(2026, 10, 4),
          ),
        ),
      );
    }
    await old;
    expect(model.monthly.totals!.entries, isEmpty);
    model.monthly.clear();
    expect(model.monthly.snapshot, isNull);
    expect(model.monthly.totals, isNull);
  });
  test('month switch ignores the previous range response', () async {
    final held = <Completer<http.Response>>[];
    final model = monthModel(
      client: MockClient((request) {
        if (request.url.queryParameters['start']!.startsWith('2026-09-') ||
            request.url.queryParameters['start'] == '2026-08-31') {
          final pending = Completer<http.Response>();
          held.add(pending);
          return pending.future;
        }
        return Future.value(fixtureForRequest(request, []));
      }),
    );
    addTearDown(model.dispose);
    model.monthly.bind(1, model.workspace!);
    final old = model.monthly.selectMonth(DateTime(2026, 9));
    await Future<void>.delayed(Duration.zero);
    await model.monthly.selectMonth(DateTime(2026, 11));
    for (final pending in held) {
      pending.complete(
        response(
          rangeFixture(
            monthFixture(),
            DateTime(2026, 8, 31),
            DateTime(2026, 10, 4),
          ),
        ),
      );
    }
    await old;
    expect(model.monthly.month, DateTime(2026, 11));
    expect(model.monthly.totals!.totalMinutes, 0);
  });
  test('failed overtime stays unavailable; cached month shows stale values on offline refresh', () async {
    var offline = false;
    final model = monthModel(
      client: MockClient((request) async {
        if (offline || request.url.queryParameters['start'] == '2026-08-31') {
          throw const ApiFailure('network', 'Offline');
        }
        return fixtureForRequest(request, monthFixture());
      }),
    );
    addTearDown(model.dispose);
    await loadFixtureMonth(model);
    expect(model.monthly.totals!.totalMinutes, 11040);
    expect(model.monthly.overtimeMinutes, isNull);
    expect(model.monthly.weeksFailure, isNotNull);
    offline = true;
    await model.monthly.refresh();
    expect(model.monthly.totals!.totalMinutes, 11040);
    expect(model.monthly.calendarFailure, isNotNull);
    expect(model.monthly.stale, true);
    expect(model.monthly.snapshot!.calendarUpdated, isNotNull);
  });
  test(
    'successful edit refreshes both ranges and keeps selected month',
    () async {
      var records = monthFixture();
      var requests = 0;
      final model = monthModel(
        client: MockClient((request) async {
          requests++;
          return fixtureForRequest(request, records);
        }),
      );
      addTearDown(model.dispose);
      await loadFixtureMonth(model);
      requests = 0;
      records = [
        for (final item in records)
          if (item['work_date'] == '2026-09-18')
            {...item, 'net_minutes': 780}
          else
            item,
      ];
      await model.monthly.afterMutation(model.account!.id, model.workspace!);
      expect(requests, 2);
      expect(model.monthly.month, DateTime(2026, 9));
      expect(model.monthly.totals!.totalMinutes, 11100);
      expect(model.monthly.overtimeMinutes, 540);
    },
  );
}
