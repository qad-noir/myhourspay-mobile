import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:myhourspay/core/api_client.dart';
import 'package:myhourspay/core/api_environment.dart';
import 'package:myhourspay/features/auth/auth_repository.dart';
import 'package:myhourspay/features/hours/repository.dart';
import 'package:myhourspay/features/session/session_model.dart';
import 'package:myhourspay/main.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'support/fixtures.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
  testWidgets(
    'native login, select workspace, save, edit conflict and logout',
    (tester) async {
      final captureKey = GlobalKey();
      if (const bool.fromEnvironment('MHP_CAPTURE')) {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final loader = FontLoader('Roboto')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync(),
              ),
            ),
          );
        await loader.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      }
      Future<void> capture(String name) async {
        if (!const bool.fromEnvironment('MHP_CAPTURE')) return;
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/brand/brand-mark.png'),
            captureKey.currentContext!,
          ),
        );
        await tester.pump();
        await tester.runAsync(() async {
          final boundary =
              captureKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('.local/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      final records = <Json>[];
      var editing = false;
      final client = ApiClient(
        ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
        transport: MockClient((request) async {
          final path = request.url.path.split('/mobile').last;
          if (path == '/auth/providers') {
            return response({
              'data': {'google': false, 'apple': false},
            });
          }
          if (path == '/auth/login') return response(tokenResponse());
          if (path == '/me') return response({'data': user});
          if (path == '/workspaces') {
            return response({
              'data': [workspace],
            });
          }
          if (request.method == 'PATCH') {
            editing = true;
            return response({
              'code': 'entry_changed',
              'message': 'This entry has changed. Reload it before saving.',
            }, 409);
          }
          if (path == '/workspaces/1/hours' && request.method == 'POST') {
            expect(request.headers['idempotency-key'], isNotEmpty);
            records.add(
              entry(date: jsonDecode(request.body)['work_date'] as String),
            );
            return response({'data': records.last}, 201);
          }
          if (path == '/workspaces/1/hours') {
            return response(hoursPage(records));
          }
          if (path == '/auth/session') return response({}, 204);
          throw StateError('Unexpected request: $path');
        }),
      );
      final model = SessionModel(
        AuthRepository(client),
        HoursRepository(client),
        MemorySessionStore(),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MhpApp(model: model),
        ),
      );
      await tester.pumpAndSettle();
      await capture('native-login');
      expect(find.text('Explore demo'), findsNothing);
      expect(find.text('Continue with Google'), findsNothing);
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
      await tester.pumpAndSettle();
      expect(find.text('Choose your workspace'), findsOneWidget);
      await tester.tap(find.text('Test workspace'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await capture('native-week');
      expect(find.text('0h 0m'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Add hours'), 300);
      await tester.tap(find.text('Add hours'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save hours'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save hours'));
      await tester.pumpAndSettle();
      expect(find.text('Hours saved to MHP.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('09:00 – 17:00'), 300);
      await tester.tap(find.text('09:00 – 17:00'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Update hours'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Update hours'));
      await tester.pumpAndSettle();
      expect(editing, isTrue);
      expect(find.text('Reload server version'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Update hours'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Update hours'),
      );
      expect(save.onPressed, isNull);
      await model.logout();
      await tester.pumpAndSettle();
      expect(find.text('Your time. In order.'), findsOneWidget);
      expect(find.text('Reload server version'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'large text on narrow login remains scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = ApiClient(
        ApiEnvironment.parse('development', 'http://localhost/api/v1/mobile'),
        transport: MockClient(
          (_) async => response({
            'data': {'google': false, 'apple': false},
          }),
        ),
      );
      await tester.pumpWidget(
        MhpApp(
          model: SessionModel(
            AuthRepository(api),
            HoursRepository(api),
            MemorySessionStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Sign in'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
