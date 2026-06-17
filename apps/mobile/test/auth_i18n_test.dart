import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/auth/auth_service.dart';
import 'package:watoto_mobile/features/auth/parent_gate.dart';
import 'package:watoto_mobile/features/library/content_i18n.dart';
import 'package:watoto_mobile/features/library/library_models.dart';

Map<String, String> _bundle(String code) =>
    (jsonDecode(File('assets/i18n/$code.json').readAsStringSync()) as Map)
        .cast<String, String>();

void main() {
  group('content i18n overlay', () {
    test('French overlays translated content, falls back to English otherwise', () {
      final en = _bundle('en');
      final fr = _bundle('fr');
      final i18n = ContentI18n({'en': en, 'fr': fr, 'sw': _bundle('sw')});

      // Stage 1 is translated in both locales.
      expect(i18n.tr('fr', 's01.cause.lesson.01.title', 'x'),
          'Touche pour faire une étoile');
      expect(i18n.tr('sw', 's01.cause.lesson.01.title', 'x'),
          'Gusa ili kutengeneza nyota');

      // Translation is partial and grows over time: any English key not yet
      // translated to French resolves to the English catalog value, not the
      // raw fallback. (Skipped only in the unlikely event FR hits 100%.)
      final untranslated =
          en.keys.firstWhere((k) => !fr.containsKey(k), orElse: () => '');
      if (untranslated.isNotEmpty) {
        expect(i18n.tr('fr', untranslated, 'fallback'), en[untranslated]);
        expect(i18n.tr('fr', untranslated, 'fallback'), isNot('fallback'));
      }

      // Unknown key returns the provided fallback.
      expect(i18n.tr('fr', 'does.not.exist', 'fallback'), 'fallback');
    });

    test('LocalizedItem localizes a Stage 1 lesson into French', () {
      final i18n = ContentI18n({'en': _bundle('en'), 'fr': _bundle('fr')});
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
