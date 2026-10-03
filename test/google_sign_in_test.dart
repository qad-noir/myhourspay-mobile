import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
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
  Future<String> acquireIdToken() async => 'fixture-provider-token';
}

SessionModel createModel(MockClient client, MemorySessionStore store) {
  final api = ApiClient(
    ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
    transport: client,
  );
  return SessionModel(AuthRepository(api), HoursRepository(api), store);
}

void main() {
  test('provider conflicts show account linking or fresh sign-in guidance', () {
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
            if (r.url.path.endsWith('/auth/google')) {
              expect(r.headers['authorization'], isNull);
              expect(jsonDecode(r.body), {
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
            () async => 'fixture-provider-token',
            () async => 'Pixel 9 (Android)',
            name: 'Test User',
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
    final pending = Completer<String>();
    final model = createModel(
      MockClient((r) async {
        requests++;
        return response({});
      }),
      MemorySessionStore(),
    );
    model.providers = {'google': true};
    Future<String> acquire() {
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
    expect(requests, 0);
    model.dispose();
  });
  test('backend-disabled Google never opens SDK', () async {
    final model = createModel(
      MockClient((r) async => response({})),
      MemorySessionStore(),
    );
    expect(
      await model.googleSignIn(
        () async => throw StateError('Must not run'),
        () async => 'Android',
      ),
      false,
    );
    expect(model.failure?.code, 'provider_unavailable');
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
  test('native configuration gates iOS separately', () {
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
        true,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
