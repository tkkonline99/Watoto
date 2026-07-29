import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../offline/offline_providers.dart';
import 'sfx_backend_io.dart'
    if (dart.library.js_interop) 'sfx_backend_web.dart';

/// Short, bundled, language-neutral interaction sounds (tap / success /
/// celebration). Respects the same on/off flag as spoken narration, and every
/// call is guarded so a missing audio device (desktop or tests) degrades to
/// silence rather than throwing. The backend is platform-split: audioplayers
/// on mobile/desktop, a plain HTMLAudioElement on web (the plugin's global
/// event channel is broken there).
class SoundEffects {
  SoundEffects(this._ref);

  final Ref _ref;
  final _backend = SfxBackend();

  bool get _enabled => _ref.read(offlineStoreProvider).narrationEnabled;

  Future<void> _play(String asset) async {
    if (!_enabled) return;
    try {
      await _backend.play(asset, 0.6);
    } catch (_) {
      // No audio device / plugin (desktop, tests) — stay silent.
    }
  }

  Future<void> tap() => _play('audio/sfx/tap.wav');
  Future<void> correct() => _play('audio/sfx/correct.wav');
  Future<void> celebrate() => _play('audio/sfx/celebrate.wav');

  /// Bigger than [celebrate] — reserved for reaching a new level.
  Future<void> levelUp() => _play('audio/sfx/levelup.wav');

  /// Coins landing.
  Future<void> coin() => _play('audio/sfx/coin.wav');

  /// A streak milestone or a streak rescued by the weekly shield.
  Future<void> streak() => _play('audio/sfx/streak.wav');

  /// A single warm chime. Smaller than [celebrate] — a star landing, or an
  /// interruption we want to feel like a reward (the stretch break).
  Future<void> star() => _play('audio/sfx/star.wav');

  /// A wrong pick. A soft downward step, never a buzzer: the child is five,
  /// and the sound should read as "try again", not "you failed".
  Future<void> retry() => _play('audio/sfx/retry.wav');
}

final soundEffectsProvider = Provider<SoundEffects>(SoundEffects.new);
