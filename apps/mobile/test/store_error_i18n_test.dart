import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/core/l10n/store_error_text.dart';
import 'package:watoto_mobile/core/offline/store_error.dart';
import 'package:watoto_mobile/l10n/gen/app_localizations.dart';

/// The store used to throw `StateError('Wrong password.')` and the parent
/// screens printed `e.message` straight out, so a Swahili or French family
/// resetting a password read English. One screen even decided what to show by
/// matching on the English text. These tests hold the replacement to its job:
/// every named cause says something, in every language, and never English by
/// accident.

const _fallback = 'FALLBACK';

Future<AppLocalizations> _load(String code) =>
    AppLocalizations.delegate.load(Locale(code));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every code maps to real text in every language', () async {
    for (final lang in ['en', 'sw', 'fr']) {
      final l10n = await _load(lang);
      for (final code in StoreErrorCode.values) {
        final text = storeErrorText(
          l10n,
          StoreError(code, days: 5),
          fallback: _fallback,
        );
        expect(text, isNotEmpty, reason: '$code in $lang is empty');
        // childNotFound has no parent-facing wording of its own; the screen's
        // generic message is the honest answer there. Every other cause must
        // say something specific.
        if (code != StoreErrorCode.childNotFound) {
          expect(
            text,
            isNot(_fallback),
            reason: '$code in $lang fell through to the generic message',
          );
        }
      }
    }
  });

  test('Swahili and French do not echo the English wording', () async {
    final en = await _load('en');
    final sw = await _load('sw');
    final fr = await _load('fr');
    // Codes whose English copy is distinctive enough that an untranslated
    // string would show up as an exact match.
    const codes = [
      StoreErrorCode.wrongPassword,
      StoreErrorCode.passwordTooShort,
      StoreErrorCode.noAccountForEmail,
      StoreErrorCode.resetCodeExpired,
      StoreErrorCode.nicknameRequired,
    ];
    for (final code in codes) {
      final e = StoreError(code);
      final english = storeErrorText(en, e, fallback: _fallback);
      expect(
        storeErrorText(sw, e, fallback: _fallback),
        isNot(english),
        reason: '$code is still English in Swahili',
      );
      expect(
        storeErrorText(fr, e, fallback: _fallback),
        isNot(english),
        reason: '$code is still English in French',
      );
    }
  });

  test('the cooldown carries its day count into the message', () async {
    final l10n = await _load('en');
    final text = storeErrorText(
      l10n,
      const StoreError(StoreErrorCode.nicknameCooldown, days: 12),
      fallback: _fallback,
    );
    expect(text, contains('12'));
  });

  test('anything that is not a StoreError gets the screen fallback', () async {
    final l10n = await _load('en');
    expect(
      storeErrorText(l10n, StateError('boom'), fallback: _fallback),
      _fallback,
    );
    expect(
      storeErrorText(l10n, Exception('nope'), fallback: _fallback),
      _fallback,
    );
  });
}
