import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../offline/offline_providers.dart';

/// Spoken narration for the audio-first bands (0–5 are "zero reading, audio
/// first"). Wraps [FlutterTts] behind a controller whose value is the
/// persisted on/off flag. Every engine call is guarded: on platforms without a
/// TTS engine — and in tests, where the plugin channel is absent — it stays
/// silent so captions still carry the lesson.
class NarrationController extends Notifier<bool> {
  FlutterTts? _tts;

  @override
  bool build() => ref.watch(offlineStoreProvider).narrationEnabled;

  static const _voice = {'en': 'en-US', 'sw': 'sw-KE', 'fr': 'fr-FR'};

  /// Speaks [text] in [langCode] when narration is on. Never throws.
  Future<void> speak(String text, String langCode) async {
    if (!state || text.trim().isEmpty) return;
    try {
      final tts = _tts ??= FlutterTts();
      await tts.stop();
      await tts.setLanguage(_voice[langCode] ?? 'en-US');
      await tts.setSpeechRate(0.45); // gentle pace for young listeners
      await tts.speak(text);
    } catch (_) {
      // No TTS engine available (desktop/test) — degrade to silent captions.
    }
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  /// Flips narration on/off and persists the choice.
  Future<void> toggle() async {
    final next = !state;
    await ref.read(offlineStoreProvider).setNarrationEnabled(next);
    state = next;
    if (!next) await stop();
  }
}

final narrationProvider = NotifierProvider<NarrationController, bool>(
  NarrationController.new,
);
