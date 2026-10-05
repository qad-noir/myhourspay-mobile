import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myhourspay/shared/widgets.dart';

void main() {
  testWidgets('shimmer moves left to right and preserves content geometry', (
    tester,
  ) async {
    Widget screen(bool loading, {bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Center(
          child: SkeletonRegion(
            loading: loading,
            child: const SizedBox(
              width: 220,
              height: 120,
              child: Text('Loaded content'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(screen(true));
    final initialSize = tester.getSize(find.byType(SkeletonRegion));
    LinearGradient gradient() =>
        (tester
                        .widget<DecoratedBox>(
                          find.descendant(
                            of: find.byType(SkeletonRegion),
                            matching: find.byType(DecoratedBox),
                          ),
                        )
                        .decoration
                    as BoxDecoration)
                .gradient!
            as LinearGradient;
    final first = gradient().begin as Alignment;
    await tester.pump(const Duration(milliseconds: 650));
    final next = gradient().begin as Alignment;
    expect(next.x, greaterThan(first.x));
    expect(next.x - first.x, closeTo(1, .05));
    await tester.pumpWidget(screen(false));
    expect(tester.getSize(find.byType(SkeletonRegion)), initialSize);
    expect(
      find.descendant(
        of: find.byType(SkeletonRegion),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    await tester.pumpWidget(screen(true, reduced: true));
    final still = gradient().begin;
    await tester.pump(const Duration(seconds: 1));
    expect(gradient().begin, still);
    expect(tester.takeException(), isNull);
  });
}
