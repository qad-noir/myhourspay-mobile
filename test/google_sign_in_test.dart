import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/core/session_store.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/auth/google_identity.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/session/session_model.dart';
import 'package:myhourspay/main.dart';
import 'package:myhourspay/shared/widgets.dart';

import 'support/fixtures.dart';

class TestGoogle implements GoogleIdentity {
  @override
  bool get configured => true;
  @override
  Future<GoogleCredential> acquireCredential(String nonce) async =>
      const GoogleCredential('fixture-provider-token', name: 'Test User');
}

SessionModel createModel(MockClient client, MemorySessionStore store) {
  final api = ApiClient(
    ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
    transport: client,
  );
  return SessionModel(AuthRepository(api), HoursRepository(api), store);
}

dynamic challengeResponse([int number = 1]) => response({
  'challenge_id':
      '00000000-0000-4000-8000-${number.toString().padLeft(12, '0')}',
  'nonce': number.toString().padLeft(64, '0'),
  'nonce_mode': 'raw',
  'expires_at': DateTime.now()
      .add(const Duration(minutes: 5))
      .toUtc()
      .toIso8601String(),
}, 201);

void main() {
  test(
    'Google linkage survives secure session serialization and app restore',
    () async {
      final saved = StoredSession.decode(
        StoredSession(
          'fixture-token',
          DateTime.now().add(const Duration(hours: 1)),
          googleLinked: true,
        ).encode(),
      );
      final store = MemorySessionStore()..value = saved;
      final model = createModel(
        MockClient((request) async {
          if (request.url.path.endsWith('/me')) return response({'data': user});
          if (request.url.path.endsWith('/workspaces')) {
            return response({
              'data': [workspace],
            });
          }
          throw StateError('Unexpected route');
        }),
        store,
      );
      addTearDown(model.dispose);
      await model.restore();
      expect(model.googleLinked, true);
      expect(
        StoredSession.decode(
          '{"access_token":"old","expires_at":"2099-01-01T00:00:00Z"}',
        ).googleLinked,
        false,
      );
    },
  );
  testWidgets(
    'Android channel receives a distinct unchanged nonce per invocation',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        NativeGoogleIdentity.channel,
        (call) async {
          calls.add(call);
          return {'idToken': 'fixture-token', 'name': 'Google Name'};
        },
      );
      final identity = NativeGoogleIdentity(
        serverClientId: 'web.apps.googleusercontent.com',
      );
      await identity.acquireCredential('1'.padLeft(64, '0'));
      await identity.acquireCredential('2'.padLeft(64, '0'));
      expect(calls.map((c) => (c.arguments as Map)['nonce']).toList(), [
        '1'.padLeft(64, '0'),
        '2'.padLeft(64, '0'),
      ]);
      expect(calls.every((c) => c.method == 'authenticate'), true);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        NativeGoogleIdentity.channel,
        null,
      );
    },
  );
  test('disposed route ignores late Google chooser completion', () async {
    var exchanges = 0;
    final pending = Completer<GoogleCredential>();
    final model = createModel(
      MockClient((request) async {
        if (request.url.path.endsWith('/challenge')) return challengeResponse();
        exchanges++;
        return response({});
      }),
      MemorySessionStore(),
    );
    model.providers = {'google': true};
    final action = model.googleSignIn(
      (nonce) => pending.future,
      () async => 'Android',
    );
    await Future<void>.delayed(Duration.zero);
    model.cancelGoogleAttempt();
    pending.complete(const GoogleCredential('fixture-token'));
    await action;
    expect(exchanges, 0);
    model.dispose();
  });
  test('repeated attempts request new challenges and send no raw nonce in exchange', () async {
    var challenges = 0;
    final seen = <String>[];
    final model = createModel(
      MockClient((request) async {
        if (request.url.path.endsWith('/challenge')) {
          expect(request.headers['authorization'], isNull);
          expect(request.body, isEmpty);
          return challengeResponse(++challenges);
        }
        final body = jsonDecode(request.body) as Map;
        expect(body.containsKey('nonce'), false);
        expect(
          body['challenge_id'],
          '00000000-0000-4000-8000-${challenges.toString().padLeft(12, '0')}',
        );
        return response({
          'code': 'google_challenge_used',
          'message': 'Used',
        }, 409);
      }),
      MemorySessionStore(),
    );
    model.providers = {'google': true};
    for (var attempt = 0; attempt < 2; attempt++) {
      expect(
        await model.googleSignIn((nonce) async {
          seen.add(nonce);
          return const GoogleCredential('fixture-token');
        }, () async => 'Android'),
        false,
      );
    }
    expect(challenges, 2);
    expect(seen.toSet().length, 2);
    expect(friendlyFailure(model.failure!), contains('start a new attempt'));
    model.dispose();
  });
  test('explicit linking uses a fresh challenge and verified bearer', () async {
    final model = createModel(
      MockClient((request) async {
        if (request.url.path.endsWith('/challenge')) return challengeResponse();
        expect(request.url.path, endsWith('/auth/providers/google/link'));
        expect(request.headers['authorization'], 'Bearer fixture-mhp-token');
        expect(jsonDecode(request.body), {
          'challenge_id': '00000000-0000-4000-8000-000000000001',
          'id_token': 'fixture-google-token',
          'current_password': 'fixture-password',
        });
        return response({'message': 'Linked'});
      }),
      MemorySessionStore(),
    );
    model.providers = {'google': true};
    model.phase = SessionPhase.authenticated;
    model.auth.api.token = 'fixture-mhp-token';
    expect(
      await model.linkGoogle(
        (nonce) async => const GoogleCredential('fixture-google-token'),
        'fixture-password',
      ),
      true,
    );
    expect(model.toast, 'Google linked successfully.');
    model.dispose();
  });

  test('logout followed by Google login gets a new challenge', () async {
    var challenges = 0;
    final nonces = <String>[];
    final model = createModel(
      MockClient((request) async {
        if (request.url.path.endsWith('/challenge')) {
          return challengeResponse(++challenges);
        }
        if (request.url.path.endsWith('/auth/google')) {
          return response(
            tokenResponse(
              status: 'authenticated',
              token: 'fixture-session',
              verified: true,
            ),
          );
        }
        if (request.url.path.endsWith('/me')) return response({'data': user});
        if (request.url.path.endsWith('/auth/session')) return response({});
        if (request.url.path.endsWith('/workspaces')) {
          return response({
            'data': [workspace],
          });
        }
        throw StateError('Unexpected route');
      }),
      MemorySessionStore(),
    );
    model.providers = {'google': true};
    Future<GoogleCredential> acquire(String nonce) async {
      nonces.add(nonce);
      return const GoogleCredential('fixture-token');
    }

    expect(await model.googleSignIn(acquire, () async => 'Android'), true);
    expect(model.googleLinked, true);
    await model.logout();
    expect(model.googleLinked, false);
    expect(model.phase, SessionPhase.signedOut);
    expect(await model.googleSignIn(acquire, () async => 'Android'), true);
    expect(challenges, 2);
    expect(nonces.toSet().length, 2);
    model.dispose();
  });
  test('all challenge rejections offer a fresh action', () {
    for (final code in [
      'google_challenge_used',
      'google_challenge_expired',
      'google_challenge_invalid',
      'google_nonce_mismatch',
    ]) {
      expect(
        friendlyFailure(ApiFailure(code, 'Server details', status: 422)),
        contains('start a new attempt'),
      );
    }
  });
  test('provider rejection never asks for invisible highlighted fields', () {
    expect(
      friendlyFailure(
        const ApiFailure(
          'invalid_provider_credential',
          'Rejected',
          status: 422,
        ),
      ),
      contains('sign-in credential'),
    );
    expect(
      friendlyFailure(
        const ApiFailure('provider_email_required', 'Rejected', status: 422),
      ),
      contains('share an email'),
    );
    expect(
      friendlyFailure(
        const ApiFailure('validation_failed', 'Rejected', status: 422),
      ),
      isNot(contains('highlighted')),
    );
  });
  test('provider conflicts show account linking or fresh sign-in guidance', () {
    expect(
      friendlyFailure(
        const ApiFailure(
          'google_signup_required',
          'Server message',
          status: 422,
        ),
      ),
      contains('choose Create account'),
    );
    expect(
      friendlyFailure(
        const ApiFailure(
          'account_link_required',
          'Server message',
          status: 409,
        ),
      ),
      contains('Sign in with your password'),
    );
    expect(
      friendlyFailure(
        const ApiFailure(
          'credential_already_used',
          'Server message',
          status: 409,
        ),
      ),
      contains('new Google or Apple'),
    );
  });
  for (final status in [
    'authenticated',
    'email_verification_required',
    'two_factor_required',
  ]) {
    test(
      'Google exchange routes $status and never stores provider credentials',
      () async {
        final store = MemorySessionStore();
        final model = createModel(
          MockClient((r) async {
            if (r.url.path.endsWith('/auth/google/challenge')) {
              return challengeResponse();
            }
            if (r.url.path.endsWith('/auth/google')) {
              expect(r.headers['authorization'], isNull);
              expect(jsonDecode(r.body), {
                'challenge_id': '00000000-0000-4000-8000-000000000001',
                'id_token': 'fixture-provider-token',
                'device_name': 'Pixel 9 (Android)',
                'name': 'Test User',
                'terms': true,
              });
              return response(
                status == 'two_factor_required'
                    ? {
                        'status': status,
                        'challenge_token': 'fixture-challenge',
                        'expires_at': DateTime.now()
                            .add(const Duration(minutes: 5))
                            .toUtc()
                            .toIso8601String(),
                      }
                    : tokenResponse(
                        status: status,
                        token: 'mhp-bearer',
                        verified: status == 'authenticated',
                      ),
              );
            }
            if (r.url.path.endsWith('/me')) return response({'data': user});
            if (r.url.path.endsWith('/workspaces')) {
              return response({
                'data': [workspace],
              });
            }
            throw StateError('Unexpected route');
          }),
          store,
        );
        model.providers = {'google': true};
        expect(
          await model.googleSignIn(
            (nonce) async => const GoogleCredential(
              'fixture-provider-token',
              name: 'Test User',
            ),
            () async => 'Pixel 9 (Android)',
            terms: true,
          ),
          true,
        );
        expect(model.phase, switch (status) {
          'authenticated' => SessionPhase.authenticated,
          'two_factor_required' => SessionPhase.twoFactorChallenge,
          _ => SessionPhase.verificationRequired,
        });
        final saved = await store.read();
        expect(
          saved?.token,
          status == 'two_factor_required' ? isNull : 'mhp-bearer',
        );
        model.dispose();
      },
    );
  }
  test('busy covers native account chooser; cancellation releases it without exchange', () async {
    var requests = 0, acquisitions = 0;
    final pending = Completer<GoogleCredential>();
    final model = createModel(
      MockClient((r) async {
        requests++;
        return challengeResponse();
      }),
      MemorySessionStore(),
    );
    model.providers = {'google': true};
    Future<GoogleCredential> acquire(String nonce) {
      acquisitions++;
      return pending.future;
    }

    final first = model.googleSignIn(acquire, () async => 'Android');
    await Future<void>.delayed(Duration.zero);
    expect(model.busy, true);
    expect(await model.googleSignIn(acquire, () async => 'Android'), false);
    pending.completeError(const ApiFailure('google_canceled', 'Canceled'));
    expect(await first, false);
    expect(model.busy, false);
    expect(acquisitions, 1);
    expect(requests, 1);
    model.dispose();
  });
  test('backend-disabled Google never opens SDK', () async {
    final model = createModel(
      MockClient((r) async => response({})),
      MemorySessionStore(),
    );
    expect(
      await model.googleSignIn(
        (nonce) async => throw StateError('Must not run'),
        () async => 'Android',
      ),
      false,
    );
    expect(model.failure?.code, 'provider_unavailable');
    model.dispose();
  });
  test('new Google account validation asks for signup consent instead of invisible fields', () async {
    final model = createModel(
      MockClient(
        (r) async => r.url.path.endsWith('/auth/google/challenge')
            ? challengeResponse()
            : response({
                'message': 'The terms field is required.',
                'code': 'validation_failed',
                'errors': {
                  'terms': ['Required'],
                  'name': ['Required'],
                },
              }, 422),
      ),
      MemorySessionStore(),
    );
    model.providers = {'google': true};
    expect(
      await model.googleSignIn(
        (nonce) async =>
            const GoogleCredential('fixture-token', name: 'Google User'),
        () async => 'Android',
      ),
      false,
    );
    expect(model.failure?.code, 'google_signup_required');
    expect(friendlyFailure(model.failure!), contains('choose Create account'));
    model.dispose();
  });
  testWidgets(
    'configured Google appears on both login and signup when backend enables it',
    (tester) async {
      final model = createModel(
        MockClient(
          (r) async => response({
            'data': {'google': true, 'apple': false},
          }),
        ),
        MemorySessionStore(),
      );
      await tester.pumpWidget(
        MhpApp(
          model: model,
          googleIdentity: TestGoogle(),
          deviceLabelLoader: () async => 'Android',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsNothing);
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'iOS Google is deferred until its adapter and client are configured',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        expect(
          NativeGoogleIdentity(serverClientId: 'web.apps.googleusercontent.com')
              .configured,
          false,
        );
        expect(
          NativeGoogleIdentity(
            serverClientId: 'web.apps.googleusercontent.com',
            iosClientId: 'ios.apps.googleusercontent.com',
          ).configured,
          false,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
