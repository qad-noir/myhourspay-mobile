import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:myhourspay/core/appearance.dart';
import 'package:myhourspay/core/web_account_links.dart';
import 'package:myhourspay/features/account/account_screen.dart';
import 'package:myhourspay/shared/widgets.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'support/fixtures.dart';
import 'support/monthly_fixtures.dart';

class MemoryAppearance implements AppearanceStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

void main() {
  setUpAll(() async {
    tz.initializeTimeZones();
    for (final font in {
      'Manrope': 'assets/fonts/Manrope.ttf',
      'DM Sans': 'assets/fonts/DMSans.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  test('appearance persists independently of session and unknown preferences use System', () async {
    final store = MemoryAppearance();
    final first = AppearanceController(store);
    await first.select(ThemeMode.dark);
    final restored = AppearanceController(store);
    await restored.load();
    expect(restored.mode, ThemeMode.dark);
    store.value = 'invalid';
    await restored.load();
    expect(restored.mode, ThemeMode.system);
    first.dispose();
    restored.dispose();
  });
  test('late preference restore cannot overwrite a user selection', () async {
    final delayed = Completer<String?>();
    final controller = AppearanceController(DelayedAppearance(delayed));
    final loading = controller.load();
    await controller.select(ThemeMode.light);
    delayed.complete('dark');
    await loading;
    expect(controller.mode, ThemeMode.light);
    controller.dispose();
  });
  test('web account links require HTTPS and reject embedded credentials', () {
    expect(
      WebAccountLinks.resolve('', 'https://example.com/'),
      'https://example.com/user/profile',
    );
    expect(
      WebAccountLinks.resolve(
        'https://example.com/settings',
        'https://other.com',
      ),
      'https://example.com/settings',
    );
    expect(
      WebAccountLinks.parse('https://mhp.glsltd.co.uk/user/profile')!.path,
      '/user/profile',
    );
    for (final link in [
      '',
      'javascript:alert(1)',
      'http://example.com',
      'https://user:password@example.com',
    ]) {
      expect(WebAccountLinks.parse(link), isNull);
    }
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'account appearance changes immediately and layouts scroll at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = AppearanceController(MemoryAppearance());
        final model = monthModel(
          client: MockClient((_) async => response({'data': []})),
        );
        addTearDown(controller.dispose);
        addTearDown(model.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(
          AppearanceScope(
            controller: controller,
            child: ListenableBuilder(
              listenable: controller,
              builder: (_, _) => MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: mhpTheme(),
                darkTheme: mhpTheme(dark: true),
                themeMode: controller.mode,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    padding: const EdgeInsets.only(top: 44, bottom: 34),
                  ),
                  child: child!,
                ),
                home: RepaintBoundary(
                  key: key,
                  child: AccountScreen(model: model),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Dark'));
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();
        expect(controller.mode, ThemeMode.dark);
        expect(
          Theme.of(tester.element(find.text('Appearance'))).brightness,
          Brightness.dark,
        );
        expect(tester.takeException(), isNull);
        Future<void> capture(String name) async {
          if (!const bool.fromEnvironment('MHP_CAPTURE') || scale != 1) return;
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            Directory('docs/account-review').createSync(recursive: true);
            File('docs/account-review/$name.png')
                .writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        }

        await tester.ensureVisible(find.text('Appearance'));
        await tester.pumpAndSettle();
        await capture('preferences-dark');
        await tester.ensureVisible(find.text('Light'));
        await tester.tap(find.text('Light'));
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.text('Appearance'))).brightness,
          Brightness.light,
        );
        await tester.ensureVisible(find.text('Appearance'));
        await tester.pumpAndSettle();
        await capture('preferences-light');
        await tester.ensureVisible(find.text('Delete account'));
        await tester.pumpAndSettle();
        expect(find.text('Edit name, phone, or password'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('System'));
        await tester.tap(find.text('System'));
        await tester.pumpAndSettle();
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.text('Appearance'))).brightness,
          Brightness.dark,
        );
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

class DelayedAppearance implements AppearanceStore {
  DelayedAppearance(this.pending);
  final Completer<String?> pending;
  @override
  Future<String?> read() => pending.future;
  @override
  Future<void> write(String value) async {}
}
