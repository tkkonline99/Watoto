import 'package:web/web.dart' as web;

/// Web SFX backend: a plain HTMLAudioElement. The audioplayers web plugin's
/// global event channel throws MissingPluginException in release builds, so
/// on web we play the bundled WAVs directly — the browser caches them after
/// the first play. Bundle assets are served under `assets/<asset-key>`.
class SfxBackend {
  web.HTMLAudioElement? _el;

  Future<void> play(String asset, double volume) async {
    _el?.pause();
    // [asset] is the key relative to the bundle's assets/ dir (matching the
    // io backend's AssetSource); the engine serves the whole bundle under a
    // second assets/ prefix, hence the doubled path.
    final el = web.HTMLAudioElement()
      ..src = 'assets/assets/$asset'
      ..volume = volume;
    _el = el;
    el.play();
  }
}
