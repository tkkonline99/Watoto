import 'dart:math';

/// FTC-style parental gate — Dart port of `auth/parentGate.ts`.
///
/// A child must not be able to create an account, enter personal info, or make
/// a purchase on their own. Per FTC guidance a parental gate should require an
/// action a young child is unlikely to complete, so we use a 3-digit
/// spelled-out number entry (not a simple yes/no). Show it before the parent
/// sign-up/in screen, data-collecting settings, or the purchase screen.
///
/// This is a gate, not authentication — it keeps young children out of adult
/// flows; real identity is Firebase Auth (see auth/FIREBASE_SETUP_FLUTTER.md).
class ParentGateChallenge {
  const ParentGateChallenge({required this.prompt, required this.answer});

  /// e.g. "four — two — nine". English; show [promptIn] to a family.
  final String prompt;

  /// e.g. "429"
  final String answer;

  /// The digits of [answer] spelled out in [languageCode] (a locale name such
  /// as `sw` or `fr_CA` is fine), or [prompt] for a language with no number
  /// words here.
  ///
  /// The gate has to open for the grown-up holding the device. Spelled in
  /// English for everyone, it asked a parent reading Swahili or French to
  /// decode a language they may not read.
  String promptIn(String languageCode) {
    final words = _numberWords[languageCode.split(RegExp('[_-]')).first];
    if (words == null) return prompt;
    return answer.split('').map((d) => words[int.parse(d)]).join(' — ');
  }
}

const _numberWords = {
  'en': [
    'zero', 'one', 'two', 'three', 'four',
    'five', 'six', 'seven', 'eight', 'nine',
  ],
  'sw': [
    'sifuri', 'moja', 'mbili', 'tatu', 'nne',
    'tano', 'sita', 'saba', 'nane', 'tisa',
  ],
  'fr': [
    'zéro', 'un', 'deux', 'trois', 'quatre',
    'cinq', 'six', 'sept', 'huit', 'neuf',
  ],
};

/// Generate a fresh spelled-out 3-digit challenge.
ParentGateChallenge makeParentGate([Random? rng]) {
  final r = rng ?? Random();
  final digits = List.generate(3, (_) => r.nextInt(10));
  return ParentGateChallenge(
    prompt: digits.map((d) => _numberWords['en']![d]).join(' — '),
    answer: digits.join(),
  );
}

/// Verify the adult's input against the active challenge (ignoring non-digits).
bool checkParentGate(String input, ParentGateChallenge challenge) =>
    input.replaceAll(RegExp(r'\D'), '') == challenge.answer;
