/// First-session guided tour — pure helpers + starter activity ids.
library;

import '../curriculum/curriculum_data.dart';
import '../library/library_models.dart';
import '../library/library_repository.dart';
import '../profiles/child_profile.dart';

/// Resolve the first guided-tour lesson for [child].
LibraryItem? firstTourItem({
  required ChildProfile child,
  required LibraryRepository library,
  DateTime? now,
}) {
  final stage = stageForBirthYear(child.birthYear, now: now).stage;
  // Prefer curated starter when available.
  if (stage <= 1) {
    final hit = library.byId['s01.cause.lesson.01'];
    if (hit != null) return hit;
  } else if (stage == 2) {
    final hit = library.byId['s02.numbers.lesson.01'];
    if (hit != null) return hit;
  } else if (stage == 3) {
    final hit = library.byId['s03.counting.lesson.01'];
    if (hit != null) return hit;
  }

  // Fallback: first lesson at their stage, else any first lesson.
  final atStage = library.all
      .where((i) => i.stage == stage && i.type == LibraryType.lesson)
      .toList();
  if (atStage.isNotEmpty) return atStage.first;
  final anyLesson =
      library.all.where((i) => i.type == LibraryType.lesson).toList();
  return anyLesson.isEmpty ? null : anyLesson.first;
}

/// Warm spoken intro for the tour (natural, short, kid-friendly).
String tourWelcomeSpeech(String nickname, String langCode) {
  final name = nickname.trim().isEmpty ? '' : nickname.trim();
  return switch (langCode) {
    'fr' => name.isEmpty
        ? 'Bienvenue ! Jouons ensemble. Touche l\'étoile avec moi.'
        : 'Bonjour $name ! Jouons ensemble. Touche l\'étoile avec moi.',
    'sw' => name.isEmpty
        ? 'Karibu! Tucheze pamoja. Gusa nyota nami.'
        : 'Habari $name! Tucheze pamoja. Gusa nyota nami.',
    _ => name.isEmpty
        ? 'Welcome! Let\'s play together. Tap the star with me.'
        : 'Hi $name! Let\'s play together. Tap the star with me.',
  };
}
