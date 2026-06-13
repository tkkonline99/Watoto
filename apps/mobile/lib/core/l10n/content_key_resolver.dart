import '../../l10n/gen/app_localizations.dart';

/// Maps bundled content keys to localized strings. Server-delivered content
/// arrives pre-localized; this resolver only covers the offline sample packs.
String resolveContentKey(AppLocalizations l10n, String key) {
  return switch (key) {
    'lessonCountingTitle' => l10n.lessonCountingTitle,
    'tapToCountPrompt' => l10n.tapToCountPrompt,
    'checkAnswerPrompt' => l10n.checkAnswerPrompt,
    'quizCountingTitle' => l10n.quizCountingTitle,
    'quizHowMany' => l10n.quizHowMany,
    _ => key,
  };
}
