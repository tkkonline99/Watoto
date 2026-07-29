/// Age-banded play presentation for library activities.
///
/// Stages 1–2 (roughly ages 0–3) get bigger targets, softer feedback, and
/// parent co-play prompts. Older stages keep the denser primary layout.
library;

/// True for infant/toddler curriculum stages (design tiers parent-led /
/// encourage-effort).
bool isToddlerStage(int stage) => stage <= 2;

/// Soft early-primary (ages ~3–5) — still larger chrome, less co-play.
bool isEarlyStage(int stage) => stage <= 4;

/// Tap / choice target size in logical pixels.
double playTargetSize({required int stage}) => isToddlerStage(stage) ? 168 : 140;

/// Choice chip minimum size.
double playChoiceMinSize({required int stage}) =>
    isToddlerStage(stage) ? 112 : 92;

/// Emoji glyph size on tap stages.
double playEmojiSize({required int stage}) => isToddlerStage(stage) ? 108 : 88;

/// Choice emoji size.
double playChoiceEmojiSize({required int stage}) =>
    isToddlerStage(stage) ? 60 : 48;

/// Illustration box on the lesson / story canvas.
double playArtSize({required int stage}) => isToddlerStage(stage) ? 168 : 140;

/// Narration caption size.
double playCaptionSize({required int stage}) => isToddlerStage(stage) ? 26 : 22;

/// Built-in co-play tips when an item has no [parentNote].
/// Kept short so a grown-up can act while looking at the child, not the phone.
String coPlayTipFor({
  required int stage,
  required String subject,
  required String? parentNote,
  required String lang,
}) {
  final note = parentNote?.trim();
  if (note != null && note.isNotEmpty) return note;
  if (!isToddlerStage(stage)) return '';

  final s = subject.toLowerCase();
  return switch (lang) {
    'fr' => _tipFr(s),
    'sw' => _tipSw(s),
    _ => _tipEn(s),
  };
}

String _tipEn(String subject) {
  if (subject.contains('motor') || subject.contains('body')) {
    return 'Sit together — copy the motion with your hands.';
  }
  if (subject.contains('sensory') || subject.contains('cause')) {
    return 'Hold the device together and cheer every tap.';
  }
  if (subject.contains('language') || subject.contains('lang')) {
    return 'Say the word out loud after your child hears it.';
  }
  if (subject.contains('object') || subject.contains('peek')) {
    return 'Play peekaboo with a real cloth after this screen.';
  }
  return 'Sit knee-to-knee, smile, and celebrate every try.';
}

String _tipFr(String subject) {
  if (subject.contains('motor') || subject.contains('body')) {
    return 'Asseyez-vous ensemble — imitez le geste avec vos mains.';
  }
  if (subject.contains('sensory') || subject.contains('cause')) {
    return 'Tenez l\'appareil ensemble et applaudissez chaque toucher.';
  }
  if (subject.contains('language') || subject.contains('lang')) {
    return 'Répétez le mot à voix haute après l\'enfant.';
  }
  return 'Asseyez-vous face à face, souriez et félicitez chaque essai.';
}

String _tipSw(String subject) {
  if (subject.contains('motor') || subject.contains('body')) {
    return 'Kaeni pamoja — rudia mwendo kwa mikono yenu.';
  }
  if (subject.contains('sensory') || subject.contains('cause')) {
    return 'Shikeni kifaa pamoja na shangilia kila mguso.';
  }
  if (subject.contains('language') || subject.contains('lang')) {
    return 'Semeni neno kwa sauti baada ya mtoto kusikia.';
  }
  return 'Kaeni uso kwa uso, tabasamu, na shangilia kila jaribio.';
}
