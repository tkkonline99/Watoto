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

  /// e.g. "four — two — nine"
  final String prompt;

  /// e.g. "429"
  final String answer;
}

const _words = [
  'zero', 'one', 'two', 'three', 'four',
  'five', 'six', 'seven', 'eight', 'nine',
];

/// Generate a fresh spelled-out 3-digit challenge.
ParentGateChallenge makeParentGate([Random? rng]) {
  final r = rng ?? Random();
  final digits = List.generate(3, (_) => r.nextInt(10));
  return ParentGateChallenge(
    prompt: digits.map((d) => _words[d]).join(' — '),
    answer: digits.join(),
  );
}

/// Verify the adult's input against the active challenge (ignoring non-digits).
bool checkParentGate(String input, ParentGateChallenge challenge) =>
    input.replaceAll(RegExp(r'\D'), '') == challenge.answer;
