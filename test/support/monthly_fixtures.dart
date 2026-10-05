// Illustrative records are test-only and never inserted into a live service.

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/hours/models.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/session/session_model.dart';

import 'fixtures.dart';

List<Json> monthFixture() {
  final records = <Json>[];
  for (
    var date = DateTime(2026, 8, 31);
    !date.isAfter(DateTime(2026, 10, 4));
    date = DateTime(date.year, date.month, date.day + 1)
  ) {
    if (date.weekday > 5) continue;
    final long = date.month == 9 && [11, 18].contains(date.day);
    records.add({
      ...entry(id: records.length + 1, date: dateKey(date)),
      'net_minutes': long ? 720 : 480,
      'start_time': long ? '07:00' : '09:00',
      'end_time': long ? '19:30' : '17:30',
    });
  }
  return records;
}

Json rangeFixture(
  List<Json> records,
  DateTime start,
  DateTime end, {
  int target = 2400,
  int page = 1,
  int pageSize = 100,
}) {
  final filtered = records.where((record) {
    final date = DateTime.parse(record['work_date'] as String);
    return !date.isBefore(start) && !date.isAfter(end);
  }).toList();
  final groups = <DateTime, int>{};
  for (final record in filtered) {
    final monday = weekStart(DateTime.parse(record['work_date'] as String));
    groups[monday] = (groups[monday] ?? 0) + (record['net_minutes'] as int);
  }
  final total = filtered.fold<int>(
    0,
    (sum, e) => sum + (e['net_minutes'] as int),
  );
  return {
    'data': filtered.skip((page - 1) * pageSize).take(pageSize).toList(),
    'meta': {
      'current_page': page,
      'last_page': filtered.isEmpty ? 1 : (filtered.length / pageSize).ceil(),
      'per_page': pageSize,
      'total': filtered.length,
    },
    'summary': {
      'total_minutes': total,
      'total_formatted': 'fixture-unused',
      'overtime_minutes': groups.values.fold<int>(
        0,
        (sum, minutes) => sum + (minutes > target ? minutes - target : 0),
      ),
      'weeks': [
        for (final item in groups.entries)
          {
            'key': dateKey(item.key),
            'number': 1,
            'start': dateKey(item.key),
            'end': dateKey(
              DateTime(item.key.year, item.key.month, item.key.day + 6),
            ),
            'minutes': item.value,
            'formatted': 'fixture-unused',
            'target_minutes': target,
            'target_formatted': 'fixture-unused',
            'variance_minutes': item.value - target,
            'variance_formatted': 'fixture-unused',
            'partial': false,
          },
      ],
    },
  };
}

http.Response fixtureForRequest(
  http.Request request,
  List<Json> records, {
  int pageSize = 100,
  int target = 2400,
}) => response(
  rangeFixture(
    records,
    DateTime.parse(request.url.queryParameters['start']!),
    DateTime.parse(request.url.queryParameters['end']!),
    page: int.parse(request.url.queryParameters['page'] ?? '1'),
    pageSize: pageSize,
    target: target,
  ),
);
SessionModel monthModel({
  List<Json>? records,
  MockClient? client,
  bool writable = true,
  int target = 2400,
  bool longName = false,
}) {
  final fixture = records ?? monthFixture();
  final api = ApiClient(
    ApiEnvironment.parse('development', 'http://fixture.invalid/api/v1/mobile'),
    transport:
        client ??
        MockClient(
          (request) async =>
              fixtureForRequest(request, fixture, target: target),
        ),
  );
  return SessionModel(
      AuthRepository(api),
      HoursRepository(api),
      MemorySessionStore(),
    )
    ..account = Account.fromJson({...user, 'name': 'Alex Morgan'})
    ..workspace = Workspace.fromJson({
      ...workspace,
      'name': longName
          ? 'Design Studio International Creative Services'
          : 'Design Studio',
      'writable': writable,
      'weekly_target_minutes': target,
      'features': {'clients_projects': false, 'timesheet_approvals': true},
    })
    ..phase = SessionPhase.authenticated;
}

Future<void> loadFixtureMonth(SessionModel model, {DateTime? month}) async {
  model.auth.api.token = 'fixture-bearer';
  model.monthly.bind(model.account!.id, model.workspace!);
  await model.monthly.selectMonth(month ?? DateTime(2026, 9));
  if (model.monthly.snapshot == null) await model.monthly.refresh();
}
