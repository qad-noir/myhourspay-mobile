import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/core/session_store.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/session/session_model.dart';
import 'package:myhourspay/features/timesheets/timesheet_repository.dart';

import 'support/fixtures.dart';

void main() {
  final environment = ApiEnvironment.parse(
    'development',
    'http://localhost/api/v1/mobile',
  );
  test(
    'unverified registration cannot load workspaces and marketing is separate',
    () async {
      final store = MemorySessionStore();
      final api = ApiClient(
        environment,
        transport: MockClient((request) async {
          expect(request.url.path.endsWith('/auth/register'), isTrue);
          final body = jsonDecode(request.body);
          expect(body['terms'], true);
          expect(body['marketing_consent'], false);
          return response(
            tokenResponse(
              status: 'email_verification_required',
              verified: false,
            ),
            201,
          );
        }),
      );
      final model = SessionModel(
        AuthRepository(api),
        HoursRepository(api),
        store,
      );
      await model.register({
        'name': 'Test User',
        'email': 'test@example.test',
        'password': 'test-only-password',
        'password_confirmation': 'test-only-password',
        'device_name': 'test',
        'terms': true,
        'marketing_consent': false,
      });
      expect(model.phase, SessionPhase.verificationRequired);
      expect(model.workspaces, isEmpty);
      expect(store.value, isNotNull);
      model.dispose();
    },
  );
  test('verified new account routes to onboarding, trial restriction cannot load hours', () async {
    for (final trial in [false, true]) {
      final api = ApiClient(
        environment,
        transport: MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return response(tokenResponse());
          }
          if (request.url.path.endsWith('/me')) {
            return response({
              'data': {
                ...user,
                'onboarding_required': true,
                'trial_choice_required': trial,
              },
            });
          }
          expect(trial, isFalse);
          return response({'data': []});
        }),
      );
      final model = SessionModel(
        AuthRepository(api),
        HoursRepository(api),
        MemorySessionStore(),
      );
      await model.login('test@example.test', 'test-password', 'test');
      expect(
        model.phase,
        trial ? SessionPhase.restricted : SessionPhase.onboardingRequired,
      );
      model.dispose();
    }
  });
  test('offline logout clears local credentials without claiming remote revocation', () async {
    final store = MemorySessionStore()
      ..value = StoredSession(
        'active',
        DateTime.now().add(const Duration(days: 1)),
      );
    final api = ApiClient(
      environment,
      transport: MockClient((_) async => throw http.ClientException('offline')),
    )..token = 'active';
    final model = SessionModel(
      AuthRepository(api),
      HoursRepository(api),
      store,
    );
    await model.logout();
    expect(store.value, isNull);
    expect(api.token, isNull);
    expect(model.workspace, isNull);
    expect(model.notice, contains('could not be confirmed'));
    model.dispose();
  });
  test(
    'HTML 401 still expires a session and 422 preserves field errors',
    () async {
      var unauthorized = true;
      final api = ApiClient(
        environment,
        transport: MockClient(
          (_) async => unauthorized
              ? http.Response('<html>Unauthorized</html>', 401)
              : response({
                  'code': 'validation_failed',
                  'message': 'Check fields',
                  'errors': {
                    'work_date': ['Already recorded.'],
                  },
                }, 422),
        ),
      )..token = 'active';
      var expired = false;
      api.onSessionFailure = (_) => expired = true;
      await expectLater(api.request('GET', '/me'), throwsA(isA<ApiFailure>()));
      expect(expired, isTrue);
      unauthorized = false;
      await expectLater(
        api.request('POST', '/workspaces/1/hours', body: {}),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.fields['work_date'],
            'field errors',
            ['Already recorded.'],
          ),
        ),
      );
      api.close();
    },
  );
  test(
    'timesheet submission and review use operation keys and review version',
    () async {
      final keys = <String>[];
      final api = ApiClient(
        environment,
        transport: MockClient((request) async {
          keys.add(request.headers['idempotency-key']!);
          final body = jsonDecode(request.body);
          if (request.url.path.endsWith('/review')) {
            expect(body['version'], 'b' * 64);
            expect(body['decision'], 'rejected');
            expect(body['review_note'], 'Please check the break.');
          } else {
            expect(body['week_start'], '2026-09-28');
          }
          return response({});
        }),
      );
      final repo = TimesheetRepository(api), submission = MutationKey();
      await repo.submit(1, DateTime(2026, 9, 28), '', submission);
      await repo.submit(1, DateTime(2026, 9, 28), '', submission);
      final sheet = Timesheet.fromJson({
        'id': 9,
        'status': 'submitted',
        'week_start': '2026-09-28',
        'version': 'b' * 64,
        'total_minutes': 450,
        'user_name': 'Test',
        'review_note': null,
      });
      await repo.review(
        1,
        sheet,
        'rejected',
        'Please check the break.',
        MutationKey(),
      );
      expect(keys[0], keys[1]);
      expect(keys[2], isNot(keys[0]));
      api.close();
    },
  );
}
