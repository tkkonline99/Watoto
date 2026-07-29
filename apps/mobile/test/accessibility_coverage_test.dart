import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The product constraints claim WCAG 2.2 AA, but most interactive surfaces
/// carried no screen-reader labels: emoji-only tiles announced Unicode names
/// ("lion face", "locked"), bare `GestureDetector`s had no button role at all,
/// and selected/locked/done states were conveyed by colour and glyph alone.
///
/// A source scan rather than a render test on purpose: this asserts that every
/// screen with tap targets has been *considered*, which is the property that
/// kept regressing. Behavioural checks live with each screen's own test.
void main() {
  /// Screens whose tap targets must carry explicit semantics.
  const surfaces = <String>[
    'lib/features/child_home/child_home_screen.dart',
    'lib/features/library/library_play_screen.dart',
    'lib/features/profiles/profile_picker_screen.dart',
    'lib/features/gamification/avatar_shop_screen.dart',
    'lib/features/onboarding/language_select_screen.dart',
    'lib/features/curriculum/curriculum_screen.dart',
    'lib/features/curriculum/subject_detail_screen.dart',
    'lib/features/curriculum/age_picker.dart',
    'lib/features/auth/account_screen.dart',
  ];

  test('every interactive surface declares screen-reader semantics', () {
    final missing = <String>[];
    for (final path in surfaces) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path moved — update this list');
      if (!file.readAsStringSync().contains('Semantics(')) missing.add(path);
    }
    expect(
      missing,
      isEmpty,
      reason: 'tap targets with no spoken label: ${missing.join(", ")}',
    );
  });

  test('labelled tiles hide their decorative innards from the reader', () {
    // Semantics(label:) alone is not enough — without ExcludeSemantics the
    // reader announces the label *and* then every emoji inside it.
    for (final path in surfaces) {
      final source = File(path).readAsStringSync();
      if (!source.contains('Semantics(')) continue;
      expect(
        source.contains('ExcludeSemantics'),
        isTrue,
        reason: '$path labels nodes but still exposes their children',
      );
    }
  });

  test('accessibility settings are all reachable from the store', () {
    // Text scale, reading ease, high contrast and reduced motion are the four
    // the design system promises; a setting that exists but is unreadable is
    // the same as no setting.
    final store =
        File('lib/core/offline/offline_store.dart').readAsStringSync();
    for (final setting in [
      'textScale',
      'dyslexiaFriendly',
      'highContrast',
      'reducedMotion',
    ]) {
      expect(store.contains(setting), isTrue, reason: '$setting missing');
    }

    final dashboard =
        File('lib/features/parent/parent_dashboard_screen.dart')
            .readAsStringSync();
    for (final provider in [
      'textScaleProvider',
      'dyslexiaFriendlyProvider',
      'highContrastProvider',
      'reducedMotionProvider',
    ]) {
      expect(
        dashboard.contains(provider),
        isTrue,
        reason: '$provider has no control in the Parent Zone',
      );
    }
  });
}
