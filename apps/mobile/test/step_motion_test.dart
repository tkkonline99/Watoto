import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/step_motion.dart';

/// The scale [BreathingArt] is applying right now, read off the rendered
/// transform rather than the controller, so this tests what a child sees.
double scaleOf(WidgetTester tester) {
  final t = tester.widget<Transform>(
    find.descendant(
      of: find.byType(BreathingArt),
      matching: find.byType(Transform),
    ).last,
  );
  return t.transform.getMaxScaleOnAxis();
}

Widget host({required bool reduceMotion}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: BreathingArt(child: Text('x')),
      ),
    );

void main() {
  setUp(() => debugDisableStepMotion = false);
  tearDown(() => debugDisableStepMotion = false);

  testWidgets('the picture breathes: its scale changes over time', (
    tester,
  ) async {
    await tester.pumpWidget(host(reduceMotion: false));
    final samples = <double>[];
    // A full breath is 2600ms; sample across one half-cycle.
    for (var i = 0; i < 6; i++) {
      samples.add(scaleOf(tester));
      await tester.pump(const Duration(milliseconds: 260));
    }
    final lo = samples.reduce((a, b) => a < b ? a : b);
    final hi = samples.reduce((a, b) => a > b ? a : b);
    expect(
      hi - lo,
      greaterThan(0.01),
      reason: 'expected a visible breathe, saw $samples',
    );
    // Small enough that the tap target does not meaningfully move.
    expect(hi - lo, lessThan(0.06), reason: 'breathe got loud: $samples');

    // Perpetual, so it must be stopped before the test ends or the tree
    // never settles.
    debugDisableStepMotion = true;
    await tester.pumpWidget(host(reduceMotion: true));
  });

  testWidgets('reduce-motion holds it perfectly still', (tester) async {
    await tester.pumpWidget(host(reduceMotion: true));
    final first = scaleOf(tester);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
      expect(scaleOf(tester), first, reason: 'moved with reduce-motion on');
    }
    // No perpetual animation is running, so this settles.
    await tester.pumpAndSettle();
  });

  testWidgets('the debug flag stops it too, so pumpAndSettle returns', (
    tester,
  ) async {
    debugDisableStepMotion = true;
    await tester.pumpWidget(host(reduceMotion: false));
    final first = scaleOf(tester);
    await tester.pump(const Duration(milliseconds: 800));
    expect(scaleOf(tester), first);
    await tester.pumpAndSettle();
  });
}
