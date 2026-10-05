
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/core/session_store.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/session/session_model.dart';

import 'support/fixtures.dart';

void main() {
  test(
    'a genuinely expired restored session still clears its bearer',
    () async {
      final store = MemorySessionStore()
        ..value = StoredSession(
          'test-token',
          DateTime.now().add(const Duration(milliseconds: 500)),
        );
      final api = ApiClient(
        ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
        transport: MockClient((request) async {
          if (request.url.path.endsWith('/auth/providers')) {
            return response({
              'data': {'google': false, 'apple': false},
            });
          }
          if (request.url.path.endsWith('/me')) return response({'data': user});
          if (request.url.path.endsWith('/workspaces')) {
            return response({
              'data': [workspace],
            });
          }
          throw StateError('Unexpected route');
        }),
      );
      final model = SessionModel(
        AuthRepository(api),
        HoursRepository(api),
        store,
      );
      addTearDown(model.dispose);
      await model.restore();
      expect(model.phase, SessionPhase.authenticated);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      expect(model.phase, SessionPhase.expired);
      expect(api.token, isNull);
      expect(store.value, isNull);
    },
  );
  test('30-day session keeps bearer through delayed profile and workspace requests', () async {
    final calls = <String>[];
    final api = ApiClient(
      ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
      transport: MockClient((request) async {
        calls.add(request.url.path);
        if (request.url.path.endsWith('/auth/login')) {
          return response({
            ...tokenResponse(),
            'expires_at': DateTime.now()
                .add(const Duration(days: 30))
                .toUtc()
                .toIso8601String(),
          });
        }
        expect(request.headers['authorization'], 'Bearer test-token');
        if (request.url.path.endsWith('/me')) {
          // Real asynchronous timers: on Chrome this gives an overflowing expiry
          // timer time to fire, unlike a widget test's fake timer zone.
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return response({'data': user});
        }
        if (request.url.path.endsWith('/workspaces')) {
          return response({
            'data': [workspace],
          });
        }
        throw StateError('Unexpected route');
      }),
    );
    final model = SessionModel(
      AuthRepository(api),
      HoursRepository(api),
      MemorySessionStore(),
    );
    addTearDown(model.dispose);
    expect(
      await model.login('test@example.test', 'fixture-password', 'Web test'),
      true,
    );
    expect(calls.length, 3);
    expect(model.phase, SessionPhase.authenticated);
    expect(api.token, 'test-token');
  });
}
