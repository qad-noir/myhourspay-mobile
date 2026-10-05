import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myhourspay/features/hours/hours_screen.dart';
import 'package:myhourspay/features/hours/models.dart';
import 'package:myhourspay/features/hours/monthly_overview_view.dart';
import 'package:myhourspay/features/session/session_model.dart';
import 'package:myhourspay/shared/widgets.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'support/monthly_fixtures.dart';

Widget preview(
  SessionModel model, {
  double scale = 1,
  bool dark = false,
  EdgeInsets safe = const EdgeInsets.only(top: 24, bottom: 16),
  GlobalKey? capture,
}) => RepaintBoundary(
  key: capture,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: mhpTheme(dark: dark),
    builder: (context, child) => phoneShell(
      context,
      MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale), padding: safe),
        child: child!,
      ),
    ),
    home: ListenableBuilder(
      listenable: model,
      builder: (_, _) => HoursScreen(model: model),
    ),
  ),
);
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
  testWidgets('first overview frame masks unavailable values with skeletons', (
    tester,
  ) async {
    final model = monthModel();
    addTearDown(model.dispose);
    model.monthly.bind(model.account!.id, model.workspace!);
    await tester.pumpWidget(
      MaterialApp(
        theme: mhpTheme(),
        home: Scaffold(
          body: MonthlyOverviewView(
            model: model,
            onAccount: () {},
            onEntry: (_) {},
          ),
        ),
      ),
    );
    expect(
      tester
          .widgetList<SkeletonRegion>(find.byType(SkeletonRegion))
          .where((s) => s.loading),
      isNotEmpty,
    );
    for (final element in find.text('Unavailable').evaluate()) {
      var masked = false;
      element.visitAncestorElements((ancestor) {
        final widget = ancestor.widget;
        if (widget is SkeletonRegion && widget.loading) masked = true;
        return true;
      });
      expect(masked, isTrue);
    }
    await tester.pump(const Duration(milliseconds: 650));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('dark monthly calendar retains readable selected-day contrast', (
    tester,
  ) async {
    final model = monthModel();
    addTearDown(model.dispose);
    await loadFixtureMonth(model);
    model.monthly.selectDay(DateTime(2026, 9, 18));
    await tester.pumpWidget(preview(model, dark: true));
    await tester.pumpAndSettle();
    final overtime = find.text('Overtime');
    final label = tester.widget<Text>(overtime);
    final card = tester.widget<Container>(
      find.ancestor(of: overtime, matching: find.byType(Container)).first,
    );
    final background = (card.decoration as BoxDecoration).color!;
    final foreground = label.style!.color!;
    final high = foreground.computeLuminance();
    final low = background.computeLuminance();
    expect((high + .05) / (low + .05), greaterThan(4.5));
    final cell = find.byKey(const ValueKey('month-day-2026-09-18'));
    await tester.ensureVisible(cell);
    final text = tester.widget<Text>(
      find.descendant(of: cell, matching: find.text('18')),
    );
    final contrast =
        (brandOrange.computeLuminance() + .05) /
        (text.style!.color!.computeLuminance() + .05);
    expect(contrast, greaterThanOrEqualTo(4.5));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'logged date selects actual entry, View entry opens editing, empty date supplies add date',
    (tester) async {
      final model = monthModel();
      addTearDown(model.dispose);
      await loadFixtureMonth(model);
      await tester.pumpWidget(preview(model));
      await tester.pumpAndSettle();
      final day = find.byKey(const ValueKey('month-day-2026-09-18'));
      await tester.ensureVisible(day);
      await tester.tap(day);
      await tester.pumpAndSettle();
      expect(model.monthly.selectedEntry!.netMinutes, 720);
      await tester.ensureVisible(find.text('View entry'));
      await tester.tap(find.text('View entry'));
      await tester.pumpAndSettle();
      expect(find.text('Update hours'), findsNWidgets(2));
      expect(find.text('07:00'), findsOneWidget);
      expect(find.text('19:30'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final empty = find.byKey(const ValueKey('month-day-2026-09-19'));
      await tester.ensureVisible(empty);
      await tester.tap(empty);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add hours'));
      await tester.pumpAndSettle();
      expect(find.text('Saturday, 19 Sep'), findsOneWidget);
    },
  );
  testWidgets(
    'month picker and arrows navigate; Week/Month selection survives Account navigation',
    (tester) async {
      final model = monthModel();
      addTearDown(model.dispose);
      await loadFixtureMonth(model);
      await tester.pumpWidget(preview(model));
      await tester.pumpAndSettle();
      await tester.tap(find.text('September 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Feb'));
      await tester.pumpAndSettle();
      expect(model.monthly.month, DateTime(2026, 2));
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(model.monthly.month, DateTime(2026, 3));
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(model.overviewMonthly, false);
      await tester.tap(find.byTooltip('Account and devices'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      expect(model.overviewMonthly, false);
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(model.monthly.month, DateTime(2026, 3));
    },
  );
  testWidgets('read-only month explains permissions and disables add', (
    tester,
  ) async {
    final model = monthModel(writable: false);
    addTearDown(model.dispose);
    await loadFixtureMonth(model);
    await tester.pumpWidget(preview(model));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add hours'))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('This workspace is read-only.'), findsOneWidget);
  });
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(430, 932),
    const Size(390, 600),
    const Size(844, 390),
  ]) {
    for (final scale in size.height < 700 ? [1.0, 2.0] : [1.0]) {
      testWidgets(
        'monthly layout ${size.width.toInt()}x${size.height.toInt()} scale $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final model = monthModel(longName: scale > 1);
          addTearDown(model.dispose);
          await loadFixtureMonth(model);
          model.monthly.selectDay(DateTime(2026, 9, 18));
          final key = GlobalKey();
          await tester.pumpWidget(
            preview(
              model,
              scale: scale,
              capture: key,
              safe: const EdgeInsets.only(top: 44, bottom: 34),
            ),
          );
          await tester.runAsync(
            () => precacheImage(
              const AssetImage('assets/brand/brand-mark.png'),
              key.currentContext!,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          Future<void> capture(String position) async {
            if (!const bool.fromEnvironment('MHP_CAPTURE') ||
                scale != 1 ||
                size.height < 700) {
              return;
            }
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final picture = await boundary.toImage(pixelRatio: 1);
              final data = await picture.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final directory = Directory('docs/monthly-review')
                ..createSync(recursive: true);
              File(
                '${directory.path}/month-${size.width.toInt()}-$position.png',
              ).writeAsBytesSync(data!.buffer.asUint8List());
              picture.dispose();
            });
          }

          await capture('top');
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, -350),
          );
          await tester.pumpAndSettle();
          await capture('calendar');
          await tester.ensureVisible(find.text('Monthly breaks'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await capture('lower');
          expect(find.text('Add hours'), findsOneWidget);
          expect(find.text('Overview'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  test('weekly labels are neutral for shortfalls, zero entries and unavailable targets', () {
    expect(
      WeeklyBreakdownRow(
        week: HoursWeek(
          start: DateTime(2026, 9, 7),
          minutes: 1800,
          targetMinutes: 2100,
        ),
      ).status,
      '5h below target',
    );
    expect(
      WeeklyBreakdownRow(
        week: HoursWeek(
          start: DateTime(2026, 9, 7),
          minutes: 0,
          targetMinutes: 2100,
        ),
      ).status,
      'No hours logged',
    );
    expect(
      WeeklyBreakdownRow(
        week: HoursWeek(
          start: DateTime(2026, 9, 7),
          minutes: 1800,
          targetMinutes: null,
        ),
      ).status,
      'Target unavailable',
    );
  });
}
