import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/auth/auth_screens.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/session/session_model.dart';
import 'package:myhourspay/shared/widgets.dart';

import 'support/fixtures.dart';

void main() {
  testWidgets(
    'workspace rejection after login disposal never accesses disposed password controller',
    (tester) async {
      final pending = Completer<http.Response>();
      final api = ApiClient(
        ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
        transport: MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return response(tokenResponse());
          }
          if (request.url.path.endsWith('/me')) return response({'data': user});
          if (request.url.path.endsWith('/workspaces')) return pending.future;
          throw StateError('Unexpected route');
        }),
      );
      final model = SessionModel(
        AuthRepository(api),
        HoursRepository(api),
        MemorySessionStore(),
      )..phase = SessionPhase.signedOut;
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: mhpTheme(),
          home: LoginScreen(
            model: model,
            deviceLabelLoader: () async => 'Web test',
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'test@example.test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'test-password',
      );
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(const SizedBox());
      pending.complete(
        response({
          'code': 'unauthenticated',
          'message': 'Unauthenticated.',
        }, 401),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(model.phase, SessionPhase.expired);
      expect(api.token, isNull);
    },
  );
}
