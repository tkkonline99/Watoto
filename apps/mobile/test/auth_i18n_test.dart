import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/auth/auth_service.dart';
import 'package:watoto_mobile/features/auth/parent_gate.dart';
import 'package:watoto_mobile/features/library/content_i18n.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
import 'package:watoto_mobile/features/library/library_repository.dart';

Map<String, String> _bundle(String code) =>
    (jsonDecode(File('assets/i18n/$code.json').readAsStringSync()) as Map)
        .cast<String, String>();

/// Every string [LocalizedItem] would pass to `tr` as its fallback, on the key
/// it would pass it under — i.e. the English the app resolves to with no
/// overlay at all.
Map<String, String> _englishFallbacks() {
  final raw =
      File('assets/content/watoto_content_library.json').readAsStringSync();
  final out = <String, String>{};
  for (final item
      in parseLibraryItems(raw)) {
    final id = item.id;
    out['$id.title'] = item.title;
    if (item.parentNote != null && item.parentNote!.isNotEmpty) {
      out['$id.parentNote'] = item.parentNote!;
    }
    for (var n = 0; n < item.steps.length; n++) {
      final st = item.steps[n];
      out['$id.steps.$n.narration'] = st.narration;
      out['$id.steps.$n.feedback'] = st.feedback;
      if (st.prompt != null) out['$id.steps.$n.prompt'] = st.prompt!;
      for (var m = 0; m < st.choices.length; m++) {
        out['$id.steps.$n.choices.$m'] = st.choices[m];
      }
    }
    for (var n = 0; n < item.questions.length; n++) {
      final q = item.questions[n];
      out['$id.questions.$n.prompt'] = q.prompt;
      out['$id.questions.$n.correctFeedback'] = q.correctFeedback;
      out['$id.questions.$n.retryFeedback'] = q.retryFeedback;
      for (var m = 0; m < q.options.length; m++) {
        out['$id.questions.$n.options.$m.label'] = q.options[m].label;
      }
    }
    for (var n = 0; n < item.pages.length; n++) {
      out['$id.pages.$n.narration'] = item.pages[n].narration;
    }
    for (var n = 0; n < item.recap.length; n++) {
      final rc = item.recap[n];
      out['$id.recap.$n.prompt'] = rc.prompt;
      for (var m = 0; m < rc.options.length; m++) {
        out['$id.recap.$n.options.$m'] = rc.options[m];
      }
    }
  }
  return out;
}

void main() {
  group('content i18n overlay', () {
    test('French overlays translated content, falls back to English otherwise', () {
      final fr = _bundle('fr');
      final i18n = ContentI18n({'fr': fr, 'sw': _bundle('sw')});

      // Stage 1 is translated in both locales.
      expect(i18n.tr('fr', 's01.cause.lesson.01.title', 'x'),
          'Touche pour faire une étoile');
      expect(i18n.tr('sw', 's01.cause.lesson.01.title', 'x'),
          'Gusa ili kutengeneza nyota');

      // Translation is partial and grows over time: any English key not yet
      // translated to French resolves to the fallback the caller passed, which
      // LocalizedItem reads off the English library.
      final untranslated = _bundle('en')
          .keys
          .firstWhere((k) => !fr.containsKey(k), orElse: () => '');
      if (untranslated.isNotEmpty) {
        expect(i18n.tr('fr', untranslated, 'from the library'),
            'from the library');
      }

      // Unknown key returns the provided fallback.
      expect(i18n.tr('fr', 'does.not.exist', 'fallback'), 'fallback');
    });

    // Why the English bundle is no longer shipped, held as a test rather than
    // as a claim in a comment.
    //
    // `content/extract_strings.py` writes assets/i18n/en.json *from* the
    // content library, so each of its values is the same string LocalizedItem
    // passes as the fallback for that key. Bundling it therefore shipped every
    // English string twice — a megabyte of install and a 12,000-entry map — to
    // resolve to what would have been resolved without it. If the two ever
    // drift, this fails and the decision has to be taken again.
    test('the English bundle only repeats the library it was extracted from',
        () {
      final en = _bundle('en');
      final library = _englishFallbacks();
      final differing = [
        for (final e in en.entries)
          if (library.containsKey(e.key) && library[e.key] != e.value) e.key,
      ];
      expect(differing, isEmpty,
          reason: 'en.json has drifted from the content library; re-run '
              'content/extract_strings.py, or start shipping en.json again');

      // Keys en.json has that the library cannot produce are dead: the app
      // only ever asks for a key it built from an item it is holding, so a key
      // for a step that no longer exists is never looked up.
      final unreachable = en.keys.where((k) => !library.containsKey(k)).length;
      expect(unreachable, lessThan(en.length ~/ 100),
          reason: '$unreachable stale keys in en.json — re-run extraction');
    });

    test('LocalizedItem localizes a Stage 1 lesson into French', () {
      final i18n = ContentI18n({'fr': _bundle('fr')});
      const item = LibraryItem(
        id: 's01.cause.lesson.01',
        stage: 1,
        ages: '0-1',
        subject: 'Cause & Effect',
        type: LibraryType.lesson,
        title: 'Tap to Make a Star',
        objective: '',
        designTier: 'parent-led',
        reading: false,
        interaction: 'tap',
        steps: [
          LessonStep(narration: 'Tap the dark sky.', action: 'tap', feedback: 'A star appears.'),
        ],
      );
      final loc = LocalizedItem(item, i18n, 'fr');
      expect(loc.title, 'Touche pour faire une étoile');
      expect(loc.stepNarration(0), 'Touche le ciel sombre.');
    });
  });

  group('parent gate (FTC)', () {
    test('accepts the answer (ignoring punctuation), rejects wrong input', () {
      final challenge = makeParentGate();
      expect(challenge.answer.length, 3);
      expect(checkParentGate(challenge.answer, challenge), isTrue);
      expect(checkParentGate('(${challenge.answer})', challenge), isTrue);
      final wrong = challenge.answer == '000' ? '111' : '000';
      expect(checkParentGate(wrong, challenge), isFalse);
    });
  });

  group('LocalAuthService', () {
    test('anonymous-first, upgrade-in-place keeps the uid', () async {
      final auth = LocalAuthService();
      final anon = await auth.ensureAnonymousSession();
      expect(anon.isAnonymous, isTrue);
      expect(anon.uid, isNotEmpty);

      final parent = await auth.signUpParent(
          email: 'a@b.com', password: 'pw123456', consent: true);
      expect(parent.isAnonymous, isFalse);
      expect(parent.uid, anon.uid); // progress carries over
      expect(parent.email, 'a@b.com');
    });

    test('sign-up requires consent', () async {
      final auth = LocalAuthService();
      await auth.ensureAnonymousSession();
      expect(
        () => auth.signUpParent(email: 'a@b.com', password: 'pw', consent: false),
        throwsStateError,
      );
    });

    test('getIdToken is null in local mode', () async {
      expect(await LocalAuthService().getIdToken(), isNull);
    });
  });
}
