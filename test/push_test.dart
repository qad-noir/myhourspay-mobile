import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/features/notifications/push_controller.dart';
import 'package:myhourspay/features/notifications/reminder_target.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/session/session_model.dart';

import 'support/fixtures.dart';

void main() {
  test('logout unregisters push before revoking the mobile bearer', () async {
    var cleaned = false;
    final api = ApiClient(
      ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
      transport: MockClient((request) async {
        expect(cleaned, isTrue);
        expect(request.method, 'DELETE');
        expect(request.url.path.endsWith('/auth/session'), isTrue);
        return response({}, 204);
      }),
    )..token = 'test-session';
    final model = SessionModel(
      AuthRepository(api),
      HoursRepository(api),
      MemorySessionStore(),
    );
    addTearDown(model.dispose);
    model.beforeLogout = () async {
      expect(api.token, 'test-session');
      cleaned = true;
    };
    await model.logout();
    expect(cleaned, isTrue);
    expect(api.token, isNull);
    expect(model.phase, SessionPhase.signedOut);
  });
  const message = {
    'type': 'missing_entry',
    'user_id': '12',
    'workspace_id': '34',
    'work_date': '2026-10-05',
  };
  test('reminder routing accepts only this account and a real work date', () {
    final target = ReminderTarget.parse(message, 12)!;
    expect(target.workspaceId, 34);
    expect(target.date, DateTime(2026, 10, 5));
    expect(ReminderTarget.parse(message, 13), isNull);
    for (final invalid in [
      '2026-02-30',
      '2026-10-05T12:00:00Z',
      'https://example.com',
      'not-a-date',
    ]) {
      expect(
        ReminderTarget.parse({...message, 'work_date': invalid}, 12),
        isNull,
      );
    }
    expect(
      ReminderTarget.parse({...message, 'workspace_id': '-1'}, 12),
      isNull,
    );
    expect(
      ReminderTarget.parse({...message, 'type': 'promotional'}, 12),
      isNull,
    );
  });
  test(
    'unconfigured builds never activate Firebase or register push devices',
    () async {
      final api = ApiClient(
        ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
        transport: MockClient(
          (_) async => throw StateError('Unexpected API request'),
        ),
      );
      final push = PushController(api);
      addTearDown(api.close);
      addTearDown(push.dispose);
      expect(push.configured, isFalse);
      await push.initialize();
      await push.sessionChanged('test-session');
      await push.setEnabled(true);
      expect(push.enabled, isFalse);
      expect(push.busy, isFalse);
      await push.beforeLogout();
      expect(push.error, isNull);
    },
  );
}
