import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myhourspay/shared/widgets.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'support/visual_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    tz.initializeTimeZones();
    for (final entry in {
      'Manrope': 'assets/fonts/Manrope.ttf',
      'DM Sans': 'assets/fonts/DMSans.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });
  for (final size in [
    const Size(390, 844),
    const Size(360, 800),
    const Size(430, 932),
  ]) {
    for (final name in visualNames) {
      testWidgets('$name at ${size.width.toInt()}px', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = visualModel();
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: mhpTheme(),
              builder: phoneShell,
              home: visualScreen(name, model),
            ),
          ),
        );
        await tester.runAsync(() async {
          for (final asset in [
            'assets/brand/brand-mark.png',
            'assets/providers/google.png',
            'assets/providers/apple.png',
          ]) {
            await precacheImage(AssetImage(asset), key.currentContext!);
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (name == 'add-hours' || name == 'weekly-timesheet') {
          final action = find.widgetWithText(
            FilledButton,
            name == 'add-hours' ? 'Save hours' : 'Submit for approval',
          );
          expect(action.hitTestable(), findsOneWidget);
          expect(tester.getBottomRight(action).dy, lessThan(size.height));
        }
        if (const bool.fromEnvironment('MHP_CAPTURE')) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dir = Directory('docs/visual-review/${size.width.toInt()}')
              ..createSync(recursive: true);
            await File('${dir.path}/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        // Opt-in, reviewed Windows/Flutter baseline. Never auto-update goldens.
        if (const bool.fromEnvironment('MHP_GOLDENS') && size.width == 390) {
          await expectLater(
            find.byKey(key),
            matchesGoldenFile('../docs/visual-review/390/$name.png'),
          );
        }
        await tester.pumpWidget(const SizedBox());
        model.dispose();
      });
    }
  }
  for (final name in visualNames) {
    testWidgets('$name large text and long names', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final model = visualModel(longNames: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: mhpTheme(),
          builder: phoneShell,
          home: visualScreen(name, model),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    });
  }
  testWidgets('phone shell stays centred on a wide browser', (tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = visualModel();
    await tester.pumpWidget(
      MaterialApp(
        theme: mhpTheme(),
        builder: phoneShell,
        home: visualScreen('sign-in', model),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Scaffold)).width, 430);
    expect(tester.getCenter(find.byType(Scaffold)).dx, 550);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  for (final name in ['sign-in', 'add-hours', 'verify', 'weekly-timesheet']) {
    testWidgets('$name keyboard leaves actions reachable', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final model = visualModel();
      await tester.pumpWidget(
        MaterialApp(
          theme: mhpTheme(),
          builder: phoneShell,
          home: visualScreen(name, model),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.widgetWithText(
        FilledButton,
        name == 'sign-in'
            ? 'Sign in'
            : name == 'add-hours'
            ? 'Save hours'
            : name == 'weekly-timesheet'
            ? 'Submit for approval'
            : 'Verify and continue',
      );
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(action).dy, lessThanOrEqualTo(544));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    });
  }
  testWidgets('MFA accepts pasted digits and recovery mode remains separate', (
    tester,
  ) async {
    final model = visualModel();
    await tester.pumpWidget(
      MaterialApp(theme: mhpTheme(), home: visualScreen('verify', model)),
    );
    await tester.pumpAndSettle();
    final input = find.byType(TextField);
    await tester.enterText(input, '123456789');
    expect(tester.widget<TextField>(input).controller!.text, '123456');
    await tester.enterText(input, '12345');
    expect(tester.widget<TextField>(input).controller!.text, '12345');
    await tester.ensureVisible(find.text('Use a recovery code'));
    await tester.tap(find.text('Use a recovery code'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'recovery-code-with-hyphens',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'recovery-code-with-hyphens',
    );
    expect(model.auth.api.token, isNull);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets('review rejection requires an explanatory note', (tester) async {
    final model = visualModel();
    await tester.pumpWidget(
      MaterialApp(
        theme: mhpTheme(),
        home: visualScreen('review-timesheet', model),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Request changes'));
    await tester.tap(find.text('Request changes'));
    await tester.pumpAndSettle();
    expect(
      find.text('Explain the requested changes in at least 10 characters.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
}
