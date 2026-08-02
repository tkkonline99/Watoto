import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/core/widgets/subject_island.dart';

/// A labelled Semantics node whose decorative innards are not excluded gets
/// read out twice over: the curated label, then the emoji's Unicode name, the
/// padlock, and the visible caption again. accessibility_coverage_test states
/// the rule; SubjectIsland — the home screen's subject tiles — was not
/// following it, because that test only scanned `features/` and this widget
/// lives in `core/widgets/`.
///
/// The exclusion has to sit *inside* the InkWell, not on the Semantics above
/// it: `excludeSemantics: true` on the outer node takes the child's tap action
/// with it and leaves a button a screen reader cannot activate. That is the
/// property the second test pins down.

Widget _host({bool locked = false, VoidCallback? onTap}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SubjectIsland(
            label: 'Maths',
            emoji: '🦁',
            color: Colors.blue,
            locked: locked,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('the tile speaks its label once, not its decoration',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host());
    await tester.pump();

    final node = tester.getSemantics(find.byType(SubjectIsland));
    expect(node.label, 'Maths');
    expect(
      node.childrenCount,
      0,
      reason: 'tile still exposes inner semantics (emoji, padlock, caption)',
    );
    handle.dispose();
  });

  testWidgets('and can still be activated by a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(_host(onTap: () => taps++));
    await tester.pump();

    expect(
      tester.getSemantics(find.byType(SubjectIsland)),
      matchesSemantics(
        label: 'Maths',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );

    await tester.tap(find.byType(SubjectIsland));
    await tester.pump();
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('a locked tile announces itself as disabled', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(locked: true));
    await tester.pump();

    expect(
      tester.getSemantics(find.byType(SubjectIsland)),
      matchesSemantics(
        label: 'Maths',
        isButton: true,
        isEnabled: false,
        hasEnabledState: true,
      ),
    );
    handle.dispose();
  });
}
