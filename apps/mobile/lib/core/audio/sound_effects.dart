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
}

final soundEffectsProvider = Provider<SoundEffects>(SoundEffects.new);
