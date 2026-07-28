/// Resolves bundled starter-pack illustrations for library items.
///
/// Art lives at `assets/images/img/sNN/<name>.png`. Missing stage folders
/// fall back to the stage-1 starter pack so the top ~20 activities always
/// show a picture.
library;

import 'package:flutter/services.dart';

import 'library_models.dart';

/// Direct id → image stem (stage-1 pack names).
const _idArt = <String, String>{
  's01.sensory.lesson.01': 'color_glow',
  's01.sensory.lesson.02': 'cloth',
  's01.cause.lesson.01': 'ball',
  's01.cause.lesson.02': 'bubbles',
  's01.object.lesson.01': 'cloth',
  's01.object.quiz.01': 'bear_wave',
  's01.lang.lesson.01': 'dada',
  's01.lang.story.01': 'clouds',
  's01.motor.lesson.01': 'bunny_clap',
  's02.animals.lesson.01': 'bird_leaf',
  's02.animals.quiz.01': 'bird_nest',
  's02.animals.story.01': 'bird_leaf',
  's02.body.lesson.01': 'baby_face',
  's02.colors.lesson.01': 'color_glow',
  's02.colors.quiz.01': 'color_glow',
  's02.sorting.lesson.01': 'box_car',
  's02.numbers.lesson.01': 'ball_bell',
  's02.music.lesson.01': 'big_drum',
  's02.music.story.01': 'bath_splash',
  's03.vocab.lesson.01': 'bird_peek',
  's03.phono.quiz.01': 'bell',
  's03.counting.lesson.01': 'ball_bell',
  's03.patterns.lesson.01': 'color_glow',
  's03.patterns.quiz.01': 'box_car',
  's03.emotions.quiz.01': 'baby_face',
};

/// Bundled illustration for [item], or null when nothing was drawn for it.
///
/// The pack is baby-and-toddler art: balls, bells, cloth, a waving bear. It
/// belongs to the stage 1–3 items it was drawn for. Handing it to older
/// activities put a rattle next to two-digit multiplication, which is worse
/// than no picture — so anything past the starter stages gets null and shows
/// its subject illustration instead.
String? artAssetForItem(LibraryItem item) {
  final id = item.id.toLowerCase();
  final title = item.title.toLowerCase();

  String fallbackS01(String stem) => 'assets/images/img/s01/$stem.png';

  if (_idArt[id] case final stem?) {
    // Always point at s01 pack on disk for the starter set (reliable).
    return fallbackS01(stem);
  }

  // Title-keyword guessing only for the ages the artwork depicts.
  if (item.stage > _artStageMax) return null;

  if (id.contains('sensory') ||
      title.contains('swirl') ||
      title.contains('contrast')) {
    return fallbackS01('color_glow');
  }
  if (title.contains('touch') || title.contains('feel')) {
    return fallbackS01('cloth');
  }
  if (title.contains('star')) return fallbackS01('ball');
  if (title.contains('bubble')) return fallbackS01('bubbles');
  if (title.contains('peekaboo') || title.contains('cloth')) {
    return fallbackS01('cloth');
  }
  if (title.contains('teddy') || title.contains('where did')) {
    return fallbackS01('bear_wave');
  }
  if (title.contains('mama') ||
      title.contains('dada') ||
      title.contains('first words')) {
    return fallbackS01('dada');
  }
  if (title.contains('goodnight') || title.contains('stars')) {
    return fallbackS01('clouds');
  }
  if (title.contains('clap')) return fallbackS01('bunny_clap');
  if (title.contains('animal') || title.contains('farm')) {
    return fallbackS01('bird_leaf');
  }
  if (title.contains('nose') || title.contains('body')) {
    return fallbackS01('baby_face');
  }
  if (title.contains('red') ||
      title.contains('blue') ||
      title.contains('yellow') ||
      title.contains('color')) {
    return fallbackS01('color_glow');
  }
  if (title.contains('big') && title.contains('small')) {
    return fallbackS01('box_car');
  }
  if (title.contains('count') ||
      title.contains('number') ||
      title.contains('carrot')) {
    return fallbackS01('ball_bell');
  }
  if (title.contains('drum')) return fallbackS01('big_drum');
  if (title.contains('bath')) return fallbackS01('bath_splash');
  if (title.contains('run') ||
      title.contains('jump') ||
      title.contains('action')) {
    return fallbackS01('bird_peek');
  }
  if (title.contains('rhyme')) return fallbackS01('bell');
  if (title.contains('feel') || title.contains('emotion')) {
    return fallbackS01('baby_face');
  }
  if (title.contains('pattern') || title.contains('opposite')) {
    return fallbackS01('color_glow');
  }

  // No keyword matched: better nothing than a random picture. The step's own
  // illustration (step_visuals.dart) carries the meaning.
  return null;
}

/// Highest stage the bundled starter artwork actually depicts.
const int _artStageMax = 3;

/// Cache of assets that exist (checked once).
final _missing = <String>{};
final _present = <String>{};

/// Returns the asset path if the bundled file exists, else null.
Future<String?> resolveArtAsset(LibraryItem item) async {
  final path = artAssetForItem(item);
  if (path == null) return null;
  if (_present.contains(path)) return path;
  if (_missing.contains(path)) return null;
  try {
    await rootBundle.load(path);
    _present.add(path);
    return path;
  } catch (_) {
    _missing.add(path);
    return null;
  }
}
