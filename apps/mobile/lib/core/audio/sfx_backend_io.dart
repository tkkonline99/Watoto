import 'package:audioplayers/audioplayers.dart';

/// Mobile/desktop SFX backend: audioplayers. (On web we bypass the plugin —
/// its global event channel throws MissingPluginException there — and use an
/// HTMLAudioElement instead; see sfx_backend_web.dart.)
class SfxBackend {
  AudioPlayer? _player;

  Future<void> play(String asset, double volume) async {
    final player = _player ??= AudioPlayer();
    await player.stop();
    await player.play(AssetSource(asset), volume: volume);
  }

  Future<void> stop() async {
    await _player?.stop();
  }
}
