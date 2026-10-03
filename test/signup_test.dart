import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/auth/signup_screen.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/session/session_model.dart';
import 'package:myhourspay/main.dart';
import 'package:myhourspay/shared/widgets.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'support/fixtures.dart';

SessionModel makeSignupModel(MockClient transport) {
  final api = ApiClient(
    ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
    transport: transport,
  );
  return SessionModel(
    AuthRepository(api),
    HoursRepository(api),
    MemorySessionStore(),
  );
}

Widget signup(SessionModel model, {bool providers = false}) => MaterialApp(
  theme: mhpTheme(),
  builder: phoneShell,
  home: ListenableBuilder(
    listenable: model,
    builder: (_, _) => SignupScreen(
      model: model,
      onSignIn: () {},
      deviceLabelLoader: () async => 'Pixel 9 (Android)',
      providerActions: providers
          ? {'google': (_, _, _) async {}, 'apple': (_, _, _) async {}}
          : {},
    ),
  ),
);
Future<void> fill(WidgetTester tester, {String pass = 'TestOnly123'}) async {
  await tester.enterText(
    find.byKey(const ValueKey('signup-name')),
    'Test User',
  );
  await tester.enterText(
    find.byKey(const ValueKey('signup-email')),
    'test@example.test',
  );
  await tester.enterText(find.byKey(const ValueKey('signup-password')), pass);
  await tester.enterText(
    find.byKey(const ValueKey('signup-password_confirmation')),
    pass,
  );
}

Future<void> consent(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(Checkbox).first);
  await tester.tap(find.byType(Checkbox).first);
  await tester.pump();
}

Future<void> create(WidgetTester tester) async {
  await tester.ensureVisible(
    find.widgetWithText(FilledButton, 'Create account'),
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    for (final item in {
      'Manrope': 'assets/fonts/Manrope.ttf',
      'DM Sans': 'assets/fonts/DMSans.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(item.key)..addFont(rootBundle.load(item.value))).load();
    }
  });
  testWidgets(
    'masking toggles retain inputs; legal consent gates requests; promotion starts checked',
    (tester) async {
      var requests = 0;
      final model = makeSignupModel(
        MockClient((_) async {
          requests++;
          return response({'message': 'Offline'}, 503);
        }),
      );
      await tester.pumpWidget(signup(model));
      await fill(tester);
      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, false);
      expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, true);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('signup-password')),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        true,
      );
      await tester.tap(find.byTooltip('Show Password'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('signup-password')),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        false,
      );
      await tester.tap(find.byTooltip('Show Confirm password'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('signup-password_confirmation')),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        false,
      );
      await create(tester);
      expect(requests, 0);
      expect(
        find.text('Please agree to the terms and privacy policy.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('signup-password')),
            )
            .controller!
            .text,
        'TestOnly123',
      );
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    },
  );
  testWidgets(
    'explicit promotional opt-out maps to false; 422 fields retain drafts',
    (tester) async {
      Map<String, dynamic>? sent;
      final model = makeSignupModel(
        MockClient((r) async {
          sent = jsonDecode(r.body);
          return response({
            'code': 'validation_failed',
            'message': 'Please check the form.',
            'errors': {
              'email': ['This email is already registered.'],
              'password_confirmation': ['Confirmation rejected.'],
            },
          }, 422);
        }),
      );
      await tester.pumpWidget(signup(model));
      await fill(tester);
      await consent(tester);
      await tester.ensureVisible(find.byType(Checkbox).last);
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      await create(tester);
      expect(sent!['marketing_consent'], false);
      expect(sent!['terms'], true);
      expect(sent!['device_name'], 'Pixel 9 (Android)');
      expect(find.text('This email is already registered.'), findsOneWidget);
      expect(find.text('Confirmation rejected.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('signup-password')),
            )
            .controller!
            .text,
        'TestOnly123',
      );
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    },
  );
  testWidgets(
    'pending submission blocks duplicates including device metadata wait',
    (tester) async {
      final reply = Completer<void>();
      var posts = 0;
      final model = makeSignupModel(
        MockClient((_) async {
          posts++;
          await reply.future;
          return response({'message': 'Try again'}, 503);
        }),
      );
      await tester.pumpWidget(signup(model));
      await fill(tester);
      await consent(tester);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pump();
      expect(find.text('Creating account…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(posts, 1);
      reply.complete();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    },
  );
  testWidgets(
    '201 routes to email verification; replacement token follows onboarding',
    (tester) async {
      final model = makeSignupModel(
        MockClient((r) async {
          final path = r.url.path;
          if (path.endsWith('/auth/providers')) return response({'data': {}});
          if (path.endsWith('/auth/register')) {
            expect(jsonDecode(r.body)['marketing_consent'], true);
            return response(
              tokenResponse(
                status: 'email_verification_required',
                token: 'restricted',
                verified: false,
              ),
              201,
            );
          }
          if (path.endsWith('/auth/email/verify')) {
            expect(r.headers['authorization'], 'Bearer restricted');
            return response(tokenResponse(token: 'replacement'));
          }
          if (path.endsWith('/me')) {
            return response({
              'data': {...user, 'onboarding_required': true},
            });
          }
          if (path.endsWith('/workspaces')) return response({'data': []});
          throw StateError('Unexpected request');
        }),
      );
      await tester.pumpWidget(
        MhpApp(deviceLabelLoader: () async => 'Test device', model: model),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await fill(tester);
      await consent(tester);
      await create(tester);
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.text('Use a recovery code'), findsNothing);
      expect(model.workspaces, isEmpty);
      expect(model.auth.api.token, 'restricted');
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Verify email'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Verify email'));
      await tester.pumpAndSettle();
      expect(model.auth.api.token, 'replacement');
      expect(model.phase, SessionPhase.onboardingRequired);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final size in [
    const Size(390, 844),
    const Size(360, 800),
    const Size(430, 932),
  ]) {
    testWidgets('signup preview ${size.width.toInt()}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = makeSignupModel(
        MockClient(
          (_) async => throw StateError('Preview must not contact API'),
        ),
      )..providers = {'google': true, 'apple': true};
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: signup(model, providers: true)),
      );
      await tester.runAsync(() async {
        for (final file in [
          'assets/brand/brand-mark.png',
          'assets/providers/google.png',
          'assets/providers/apple.png',
        ]) {
          await precacheImage(AssetImage(file), key.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('MHP_CAPTURE')) {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final picture = await boundary.toImage();
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final folder = Directory('docs/signup-review/${size.width.toInt()}')
            ..createSync(recursive: true);
          await File('${folder.path}/signup.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }
      await tester.ensureVisible(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    });
  }
  testWidgets(
    'large text and keyboard remain scrollable; unavailable providers hide divider',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = makeSignupModel(MockClient((_) async => response({})));
      await tester.pumpWidget(
        MaterialApp(
          theme: mhpTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.6),
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: SignupScreen(model: model, onSignIn: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('or continue with'), findsNothing);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Create account').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    },
  );
}
