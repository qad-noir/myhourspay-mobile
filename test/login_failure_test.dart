import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/core/session_store.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/session/session_model.dart';
import 'package:myhourspay/shared/widgets.dart';

import 'support/fixtures.dart';

class FailingStore extends MemorySessionStore {
  @override
  Future<void> write(StoredSession value) async => throw StateError('storage');
}

void main() {
  test('public login rejection is not a session expiry', () async {
    final api = ApiClient(
      ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
      transport: MockClient((_) async => response({}, 401)),
    );
    final model = SessionModel(
      AuthRepository(api),
      HoursRepository(api),
      MemorySessionStore(),
    )..phase = SessionPhase.expired;
    expect(await model.login('test@example.test', 'test', 'test'), false);
    expect(model.phase, SessionPhase.signedOut);
    expect(model.failure?.status, 401);
    expect(friendlyFailure(model.failure!), isNot(contains('expired')));
    model.dispose();
  });
  test(
    'incompatible login shape is not described as a device security error',
    () async {
      final api = ApiClient(
        ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
        transport: MockClient((_) async => response({'token': 'old-contract'})),
      );
      final model = SessionModel(
        AuthRepository(api),
        HoursRepository(api),
        MemorySessionStore(),
      );
      expect(await model.login('test@example.test', 'test', 'test'), false);
      expect(model.failure?.code, 'invalid_response');
      expect(api.token, isNull);
      model.dispose();
    },
  );
  test(
    'secure storage failure revokes the issued token and stays signed out',
    () async {
      var revoked = false;
      final api = ApiClient(
        ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
        transport: MockClient((request) async {
          if (request.method == 'DELETE') {
            revoked = true;
            expect(request.headers['authorization'], 'Bearer test-token');
            return response({});
          }
          return response(tokenResponse());
        }),
      );
      final model = SessionModel(
        AuthRepository(api),
        HoursRepository(api),
        FailingStore(),
      );
      expect(await model.login('test@example.test', 'test', 'test'), false);
      expect(revoked, true);
      expect(api.token, isNull);
      expect(model.phase, SessionPhase.signedOut);
      expect(model.failure?.code, 'storage_error');
      model.dispose();
    },
  );
}
