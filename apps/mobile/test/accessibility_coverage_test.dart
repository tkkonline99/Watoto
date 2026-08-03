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
    // The auth screens (login, account, both resets) build every tap target
    // out of these shared widgets, so this is where their semantics live.
    'lib/features/auth/auth_widgets.dart',
    // Shared widgets used to be out of scope here, and both of these slipped
    // through because of it: SubjectIsland (the home subject tiles) labelled
    // its node but let the reader walk into the emoji, the padlock and the
    // caption underneath, and the mascot announced its English name plus
    // "lion face" in every language. A screen is only as accessible as the
    // widgets it is built from, so the shared ones are checked too.
    'lib/core/widgets/subject_island.dart',
    'lib/core/widgets/mascot_widget.dart',
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
        source.contains('ExcludeSemantics') ||
            source.contains('excludeSemantics:'),
        isTrue,
        reason: '$path labels nodes but still exposes their children',
      );
    }
  });

  test('accessibility settings are all reachable from the store', () {
    // Text scale, reading ease, high contrast and reduced motion are the four
    // the design system promises; a setting that exists but is unreadable is
    // the same as no setting.
    // The store is one library spread over offline_store.dart and its part
    // files, so read all of them — the settings facet is not in the main file.
    final store = Directory('lib/core/offline')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.split(RegExp(r'[/\\]')).last
            .startsWith('offline_store'))
        .map((f) => f.readAsStringSync())
        .join('\n');
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
