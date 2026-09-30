import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/session_store.dart';

const user = {
  'id': 1,
  'name': 'Test User',
  'email': 'test@example.test',
  'email_verified': true,
  'two_factor_enabled': false,
  'onboarding_required': false,
  'trial_choice_required': false,
};
const workspace = {
  'id': 1,
  'name': 'Test workspace',
  'currency': 'GBP',
  'default_break_minutes': 30,
  'default_break_type': 'unpaid',
  'weekly_target_minutes': 2400,
  'role': 'owner',
  'writable': true,
  'timezone': 'Europe/London',
  'features': {'clients_projects': false, 'timesheet_approvals': false},
};
Json tokenResponse({
  String status = 'authenticated',
  String token = 'test-token',
  bool verified = true,
}) => {
  'status': status,
  'token_type': 'Bearer',
  'access_token': token,
  'expires_at': DateTime.now()
      .add(const Duration(days: 1))
      .toUtc()
      .toIso8601String(),
  'user': {...user, 'email_verified': verified},
};
Json entry({
  int id = 1,
  String date = '2026-09-28',
  String version =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
}) => {
  'id': id,
  'workspace_id': 1,
  'project_id': null,
  'timesheet_id': null,
  'work_date': date,
  'start_time': '09:00',
  'end_time': '17:00',
  'break_minutes': 30,
  'break_type': 'unpaid',
  'notes': null,
  'billable': false,
  'net_minutes': 450,
  'version': version,
};
Json hoursPage(List<Json> entries) => {
  'data': entries,
  'meta': {
    'current_page': 1,
    'last_page': 1,
    'per_page': 100,
    'total': entries.length,
  },
  'summary': {
    'total_minutes': entries.length * 450,
    'total_formatted': '07:30',
    'overtime_minutes': 0,
    'weeks': [],
  },
};
http.Response response(
  Object data, [
  int status = 200,
  Map<String, String>? headers,
]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json', ...?headers},
);

class MemorySessionStore implements SessionStore {
  StoredSession? value;
  @override
  Future<StoredSession?> read() async => value;
  @override
  Future<void> write(StoredSession value) async => this.value = value;
  @override
  Future<void> clear() async => value = null;
}
