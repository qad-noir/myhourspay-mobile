import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/core/session_store.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/hours/models.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/session/session_model.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'support/fixtures.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
  final environment = ApiEnvironment.parse(
    'development',
    'http://localhost:8000/api/v1/mobile',
  );
  test('configuration fails closed and protects the API base', () {
    expect(() => ApiEnvironment.parse('', ''), throwsFormatException);
    expect(
      () => ApiEnvironment.parse(
        'development',
        'https://mhp.glsltd.co.uk/api/v1/mobile',
      ),
      throwsFormatException,
    );
    expect(
      () =>
          ApiEnvironment.parse('staging', 'http://staging.test/api/v1/mobile'),
      throwsFormatException,
    );
    expect(
      () => ApiEnvironment.parse(
        'development',
        'http://localhost/api/v1/mobile',
        release: true,
      ),
      throwsFormatException,
    );
    expect(
      () => environment.endpoint('//evil.test', null),
      throwsFormatException,
    );
    expect(
      () => environment.endpoint('/../outside', null),
      throwsFormatException,
    );
    expect(
      environment.trusts(Uri.parse('http://localhost:8000/api/user')),
      isFalse,
    );
  });
  test('JSON headers, bearer confinement and redirect refusal', () async {
    var calls = 0;
    final api = ApiClient(
      environment,
      transport: MockClient((request) async {
        calls++;
        expect(request.headers['accept'], 'application/json');
        expect(request.followRedirects, isFalse);
        expect(request.headers['authorization'], 'Bearer test-secret');
        return response(
          {'code': 'redirect', 'message': 'Moved'},
          302,
          {'location': 'https://other.test'},
        );
      }),
    )..token = 'test-secret';
    await expectLater(
      api.request('GET', '/me'),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 302)),
    );
    expect(calls, 1);
    api.close();
  });
  test('429 enforces Retry-After without another request', () async {
    var calls = 0;
    final api = ApiClient(
      environment,
      transport: MockClient((_) async {
        calls++;
        return response(
          {'code': 'rate_limited', 'message': 'Wait'},
          429,
          {'retry-after': '60'},
        );
      }),
    );
    for (var i = 0; i < 2; i++) {
      await expectLater(
        api.request('GET', '/auth/providers', authenticated: false),
        throwsA(
          isA<ApiFailure>().having((e) => e.retryAt, 'retry time', isNotNull),
        ),
      );
    }
    expect(calls, 1);
    api.close();
  });
  test('write timeout never automatically retries', () async {
    var calls = 0;
    final api = ApiClient(
      environment,
      timeout: const Duration(milliseconds: 5),
      transport: MockClient((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return response({});
      }),
    );
    await expectLater(
      api.request('POST', '/workspaces', body: {}),
      throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'timeout')),
    );
    expect(calls, 1);
    api.close();
  });
  test('MFA challenge is not stored or sent as bearer; verification replaces restricted token', () async {
    final store = MemorySessionStore();
    final api = ApiClient(
      environment,
      transport: MockClient((request) async {
        switch (request.url.path.split('/mobile').last) {
          case '/auth/login':
            return response({
              'status': 'two_factor_required',
              'challenge_token': 'c' * 64,
              'expires_at': DateTime.now()
                  .add(const Duration(minutes: 5))
                  .toIso8601String(),
            });
          case '/auth/two-factor':
            expect(request.headers['authorization'], isNull);
            expect(jsonDecode(request.body)['challenge_token'], 'c' * 64);
            return response(
              tokenResponse(
                status: 'email_verification_required',
                token: 'restricted',
                verified: false,
              ),
            );
          case '/auth/email/verify':
            expect(request.headers['authorization'], 'Bearer restricted');
            return response(tokenResponse(token: 'normal'));
          case '/me':
            return response({'data': user});
          case '/workspaces':
            return response({
              'data': [workspace],
            });
          default:
            throw StateError('Unexpected request');
        }
      }),
    );
    final model = SessionModel(
      AuthRepository(api),
      HoursRepository(api),
      store,
    );
    await model.login('test@example.test', 'password', 'test');
    expect(model.phase, SessionPhase.twoFactorChallenge);
    expect(store.value, isNull);
    expect(api.token, isNull);
    await model.completeMfa('123456', false);
    expect(model.phase, SessionPhase.verificationRequired);
    expect(store.value?.token, 'restricted');
    expect(model.workspaces, isEmpty);
    await model.verify('123456');
    expect(store.value?.token, 'normal');
    expect(model.phase, SessionPhase.authenticated);
    model.dispose();
  });
  test(
    'expired stored token clears before making an authenticated request',
    () async {
      final store = MemorySessionStore()
        ..value = StoredSession('expired', DateTime(2000));
      final api = ApiClient(
        environment,
        transport: MockClient((request) async {
          expect(request.headers['authorization'], isNull);
          return response({
            'data': {'google': false, 'apple': false},
          });
        }),
      );
      final model = SessionModel(
        AuthRepository(api),
        HoursRepository(api),
        store,
      );
      await model.restore();
      expect(model.phase, SessionPhase.expired);
      expect(store.value, isNull);
      model.dispose();
    },
  );
  test('403 feature rejection does not clear credentials, 401 does', () async {
    var status = 403;
    final store = MemorySessionStore()
      ..value = StoredSession(
        'active',
        DateTime.now().add(const Duration(days: 1)),
      );
    final api = ApiClient(
      environment,
      transport: MockClient(
        (_) async => response({
          'code': status == 403 ? 'feature_unavailable' : 'unauthenticated',
          'message': 'Denied',
        }, status),
      ),
    )..token = 'active';
    final model = SessionModel(
      AuthRepository(api),
      HoursRepository(api),
      store,
    );
    await expectLater(
      api.request('GET', '/workspaces'),
      throwsA(isA<ApiFailure>()),
    );
    expect(store.value, isNotNull);
    status = 401;
    await expectLater(
      api.request('GET', '/workspaces'),
      throwsA(isA<ApiFailure>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(store.value, isNull);
    expect(model.phase, SessionPhase.expired);
    model.dispose();
  });
  test('idempotent edits retain key and send version; changed payload gets a new key', () async {
    final keys = <String>[];
    final api = ApiClient(
      environment,
      transport: MockClient((request) async {
        keys.add(request.headers['idempotency-key']!);
        expect(request.method, 'PATCH');
        expect(jsonDecode(request.body)['version'], 'a' * 64);
        return response({'data': entry()});
      }),
    );
    final repository = HoursRepository(api), mutation = MutationKey();
    final original = HoursEntry.fromJson(entry());
    HoursDraft draft(String note) => HoursDraft(
      date: DateTime(2026, 9, 28),
      start: '09:00',
      end: '17:00',
      breakMinutes: 30,
      paidBreak: false,
      notes: note,
    );
    await repository.save(1, draft('one'), mutation, existing: original);
    await repository.save(1, draft('one'), mutation, existing: original);
    await repository.save(1, draft('two'), mutation, existing: original);
    expect(keys[0], keys[1]);
    expect(keys[1], isNot(keys[2]));
    api.close();
  });
  test(
    'stale workspace response cannot replace new workspace records',
    () async {
      final pending = Completer<void>();
      final api = ApiClient(
        environment,
        transport: MockClient((request) async {
          if (request.url.path.contains('/workspaces/1/')) {
            await pending.future;
            return response(hoursPage([entry()]));
          }
          return response(hoursPage([]));
        }),
      );
      final model = SessionModel(
        AuthRepository(api),
        HoursRepository(api),
        MemorySessionStore(),
      );
      final old = model.selectWorkspace(Workspace.fromJson(workspace));
      await model.selectWorkspace(Workspace.fromJson({...workspace, 'id': 2}));
      pending.complete();
      await old;
      expect(model.workspace?.id, 2);
      expect(model.page?.entries, isEmpty);
      model.dispose();
    },
  );
  test('validation follows contract limits and calendar weeks', () {
    final draft = HoursDraft(
      date: DateTime(2026),
      start: '23:00',
      end: '02:00',
      breakMinutes: 30,
      paidBreak: true,
      notes: 'a' * 501,
    );
    expect(draft.validate(), contains('end_time'));
    expect(draft.validate(), contains('notes'));
    expect(dateKey(weekStart(DateTime(2027, 1, 1))), '2026-12-28');
  });
  test('pinned contract contains implemented shapes and operations', () {
    final spec = jsonDecode(
      File('docs/api/mobile.openapi.yaml').readAsStringSync(),
    ) as Json;
    expect(spec['info']['version'], '2.2.0');
    expect(
      spec['components']['schemas']['TokenResponse']['required'],
      containsAll(['status', 'access_token']),
    );
    expect(
      spec['paths']['/workspaces/{workspace}/hours/{entry}']['patch'],
      isNotNull,
    );
    expect(
      spec['components']['schemas']['HoursInput']['properties']['notes']['maxLength'],
      500,
    );
  });
}
