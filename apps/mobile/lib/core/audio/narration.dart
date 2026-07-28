import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../offline/offline_providers.dart';

/// Spoken narration for audio-first bands. Wraps [FlutterTts] with:
/// - preferred natural/enhanced voices when the OS offers them
/// - gentler rate + slightly warmer pitch for young listeners
/// - sentence chunking + short pauses so speech sounds less robotic
///
/// Every engine call is guarded: missing TTS / tests degrade to silence.
class NarrationController extends Notifier<bool> {
  FlutterTts? _tts;
  bool _configured = false;
  String? _langReady;
  final Map<String, Map<String, String>> _preferredVoice = {};

  @override
  bool build() => ref.watch(offlineStoreProvider).narrationEnabled;

  static const _locale = {'en': 'en-US', 'sw': 'sw-KE', 'fr': 'fr-FR'};

  /// Slightly different pacing per language (research: FR/SW benefit from
  /// a touch slower for clarity on stock engines).
  // Slightly slower = clearer for kids on stock Chrome/Windows voices.
  static double _rateFor(String lang) => switch (lang) {
        'fr' => 0.38,
        'sw' => 0.36,
        _ => 0.40,
      };

  /// Soft, friendly pitch — not cartoonish, not flat.
  static double _pitchFor(String lang) => switch (lang) {
        'fr' => 1.08,
        'sw' => 1.10,
        _ => 1.08,
      };

  Future<FlutterTts> _engine() async {
    final tts = _tts ??= FlutterTts();
    if (!_configured) {
      try {
        await tts.awaitSpeakCompletion(true);
      } catch (_) {}
      try {
        // iOS / some Android builds — keep audio in playback category.
        await tts.setSharedInstance(true);
      } catch (_) {}
      try {
        await tts.setVolume(1.0);
      } catch (_) {}
      _configured = true;
    }
    return tts;
  }

  /// Picks the most "natural" available voice for [localeTag].
  /// Prefers names containing neural / natural / premium / enhanced / google.
  Future<void> _ensureVoice(FlutterTts tts, String langCode) async {
    final localeTag = _locale[langCode] ?? 'en-US';
    if (_langReady == localeTag && _preferredVoice.containsKey(langCode)) {
      try {
        await tts.setVoice(_preferredVoice[langCode]!);
      } catch (_) {}
      return;
    }

    await tts.setLanguage(localeTag);

    try {
      final raw = await tts.getVoices;
      if (raw is List) {
        final voices = <Map<String, String>>[];
        for (final v in raw) {
          if (v is Map) {
            voices.add({
              for (final e in v.entries)
                '${e.key}': '${e.value}',
            });
          }
        }
        final langPrefix = localeTag.split('-').first.toLowerCase();
        final candidates = voices.where((v) {
          final loc = (v['locale'] ?? v['localeId'] ?? '').toLowerCase();
          return loc.startsWith(langPrefix) || loc.contains(localeTag.toLowerCase());
        }).toList();

        int score(Map<String, String> v) {
          final name = (v['name'] ?? v['voice'] ?? '').toLowerCase();
          var s = 0;
          if (name.contains('neural')) s += 50;
          if (name.contains('natural')) s += 45;
          if (name.contains('premium')) s += 40;
          if (name.contains('enhanced')) s += 35;
          if (name.contains('wavenet')) s += 35;
          if (name.contains('google')) s += 25;
          if (name.contains('samantha') || name.contains('karen') || name.contains('moira')) {
            s += 20; // friendly iOS system voices
          }
          if (name.contains('female') || name.contains('woman')) s += 8;
          if (name.contains('compact')) s -= 15;
          if (name.contains('eloquence')) s -= 5;
          return s;
        }

        candidates.sort((a, b) => score(b).compareTo(score(a)));
        if (candidates.isNotEmpty) {
          final best = candidates.first;
          final voice = <String, String>{
            if (best['name'] != null) 'name': best['name']!,
            if (best['locale'] != null) 'locale': best['locale']!,
            if (best['localeId'] != null && best['locale'] == null)
              'locale': best['localeId']!,
          };
          if (voice['name'] != null) {
            _preferredVoice[langCode] = voice;
            await tts.setVoice(voice);
          }
        }
      }
    } catch (_) {
      // Voice enumeration unsupported — language alone is fine.
    }

    await tts.setSpeechRate(_rateFor(langCode));
    await tts.setPitch(_pitchFor(langCode));
    _langReady = localeTag;
  }

  /// Soften robotic / code-heavy text so TTS sounds like a friendly coach.
  static String naturalize(String text) {
    var t = text.trim();
    if (t.isEmpty) return t;

    // Speak code the way a teacher would — never "print open-paren quote".
    t = t.replaceAllMapped(
      RegExp(r'print\s*\(\s*"([^"]*)"\s*\)'),
      (m) => 'print, quote ${m[1]}, quote',
    );
    t = t.replaceAllMapped(
      RegExp(r'print\s*\(\s*([a-zA-Z_][\w]*)\s*\)'),
      (m) => 'print ${m[1]}',
    );
    t = t.replaceAllMapped(
      RegExp(r'for\s+\w+\s+in\s+range\s*\(\s*(\d+)\s*\)'),
      (m) => 'for each number in range ${m[1]}',
    );
    t = t.replaceAllMapped(
      RegExp(r'(\w+)\s*=\s*"([^"]*)"'),
      (m) => '${m[1]} equals quote ${m[2]}, quote',
    );
    t = t.replaceAllMapped(
      RegExp(r'(\w+)\s*=\s*(\d+)'),
      (m) => '${m[1]} equals ${m[2]}',
    );
    t = t.replaceAll('>=', ' is at least ');
    t = t.replaceAll('<=', ' is at most ');
    t = t.replaceAll('==', ' equals ');
    t = t.replaceAll('!=', ' is not ');
    t = t.replaceAll('÷', ' divided by ');
    t = t.replaceAll('×', ' times ');
    t = t.replaceAllMapped(RegExp(r'(\d+)\s*/\s*(\d+)'), (m) => '${m[1]} divided by ${m[2]}');
    // Soften bossy imperatives for kids.
    t = t.replaceFirst(RegExp(r'^Type:\s*', caseSensitive: false), 'Let us write: ');
    t = t.replaceFirst(RegExp(r'^Solve\s+', caseSensitive: false), 'Let us solve ');
    t = t.replaceAll(RegExp(r'\bpress RUN\b', caseSensitive: false), 'press the big run button');
    t = t.replaceAll(RegExp(r'\bRUN\b'), 'run');

    // Strip leftover symbols TTS mangles.
    t = t.replaceAll(RegExp(r'[{}();:]'), ', ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Ensure terminal punctuation so the engine doesn't trail off flatly.
    if (!RegExp(r'[.!?…]$').hasMatch(t)) {
      t = '$t.';
    }
    // Light spacing after commas/colons helps some engines.
    t = t.replaceAllMapped(RegExp(r'([,;:])(\S)'), (m) => '${m[1]} ${m[2]}');
    return t;
  }

  /// Split into speakable chunks (sentences) so long prompts get natural pauses.
  static List<String> chunkForSpeech(String text) {
    final t = naturalize(text);
    final parts = t
        .split(RegExp(r'(?<=[.!?…])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return [t];
    // Merge only very tiny fragments so short sentences still pause.
    final merged = <String>[];
    final buf = StringBuffer();
    for (final p in parts) {
      if (buf.isEmpty) {
        buf.write(p);
      } else if (buf.length < 24 && p.length < 24) {
        buf.write(' $p');
      } else {
        merged.add(buf.toString());
        buf.clear();
        buf.write(p);
      }
    }
    if (buf.isNotEmpty) merged.add(buf.toString());
    return merged;
  }

  /// Speaks [text] in [langCode] when narration is on. Never throws.
  /// Optional [emotion]: 'cheer' raises pitch slightly; 'calm' lowers rate.
  Future<void> speak(
    String text,
    String langCode, {
    SpeakStyle style = SpeakStyle.lesson,
  }) async {
    if (!state || text.trim().isEmpty) return;
    try {
      final tts = await _engine();
      await tts.stop();
      await _ensureVoice(tts, langCode);

      var rate = _rateFor(langCode);
      var pitch = _pitchFor(langCode);
      switch (style) {
        case SpeakStyle.cheer:
          pitch = (pitch + 0.06).clamp(0.5, 2.0);
          rate = (rate + 0.03).clamp(0.1, 1.0);
        case SpeakStyle.hint:
          rate = (rate - 0.04).clamp(0.1, 1.0);
          pitch = (pitch - 0.02).clamp(0.5, 2.0);
        case SpeakStyle.lesson:
          break;
      }
      await tts.setSpeechRate(rate);
      await tts.setPitch(pitch);

      final chunks = chunkForSpeech(text);
      for (var i = 0; i < chunks.length; i++) {
        if (!state) break;
        await tts.speak(chunks[i]);
        // Brief inter-sentence breath (awaitSpeakCompletion already waited).
        if (i < chunks.length - 1) {
          // Slightly longer breath between sentences = less robotic.
          await Future<void>.delayed(const Duration(milliseconds: 280));
        }
      }
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

/// Cadence hint for the TTS engine.
enum SpeakStyle { lesson, cheer, hint }

final narrationProvider = NotifierProvider<NarrationController, bool>(
  NarrationController.new,
);
