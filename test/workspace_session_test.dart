import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/session/session_model.dart';

import 'support/fixtures.dart';

void main() {
  for (final status in [401, 403, 503]) {
    test('workspace HTTP $status preserves correct session boundary', () async {
      final store = MemorySessionStore();
      final api = ApiClient(
        ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
        transport: MockClient((r) async {
          if (r.url.path.endsWith('/auth/login')) {
            return response(tokenResponse());
          }
          expect(r.headers['authorization'], 'Bearer test-token');
          if (r.url.path.endsWith('/me')) return response({'data': user});
          return response({'message': 'Unauthenticated.'}, status);
        }),
      );
      final model = SessionModel(
        AuthRepository(api),
        HoursRepository(api),
        store,
      );
      expect(await model.login('test@example.test', 'test', 'web'), false);
      expect(model.workspaces, isEmpty);
      if (status == 401) {
        expect(model.phase, SessionPhase.expired);
        expect(store.value, isNull);
        expect(api.token, isNull);
        expect(model.notice, 'Your session has expired. Please sign in again.');
      } else {
        expect(model.phase, SessionPhase.restoring);
        expect(api.token, 'test-token');
        expect(store.value, isNotNull);
      }
      model.dispose();
    });
  }
}
