import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../offline/offline_providers.dart';

/// Short, bundled, language-neutral interaction sounds (tap / success /
/// celebration). Respects the same on/off flag as spoken narration, and — like
/// the TTS layer — every call is guarded so a missing audio device (desktop or
/// tests) degrades to silence rather than throwing.
class SoundEffects {
  SoundEffects(this._ref);

  final Ref _ref;
  AudioPlayer? _player;

  bool get _enabled => _ref.read(offlineStoreProvider).narrationEnabled;

  Future<void> _play(String asset) async {
    if (!_enabled) return;
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource(asset), volume: 0.6);
    } catch (_) {
      // No audio device / plugin (desktop, tests) — stay silent.
    }
  }

  Future<void> tap() => _play('audio/sfx/tap.wav');
  Future<void> correct() => _play('audio/sfx/correct.wav');
  Future<void> celebrate() => _play('audio/sfx/celebrate.wav');
}

final soundEffectsProvider = Provider<SoundEffects>(SoundEffects.new);
