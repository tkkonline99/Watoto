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

  /// How each language says the symbols that appear in lesson text.
  ///
  /// Without this the engine either skips them or an English word is spoken
  /// mid-sentence — a French child heard "3 times 4" inside an otherwise
  /// French question.
  static const _symbolWords = <String, Map<String, String>>{
    'en': {
      '=': ' equals ',
      '+': ' plus ',
      '×': ' times ',
      '÷': ' divided by ',
      '%': ' percent ',
      '>': ' is greater than ',
      '<': ' is less than ',
      'minus': ' minus ',
      'point': ' point ',
      'blank': 'what',
    },
    'sw': {
      '=': ' ni sawa na ',
      '+': ' jumlisha ',
      '×': ' mara ',
      '÷': ' gawanya kwa ',
      '%': ' asilimia ',
      '>': ' ni kubwa kuliko ',
      '<': ' ni ndogo kuliko ',
      'minus': ' toa ',
      'point': ' nukta ',
      'blank': 'nini',
    },
    'fr': {
      '=': ' égale ',
      '+': ' plus ',
      '×': ' fois ',
      '÷': ' divisé par ',
      '%': ' pour cent ',
      '>': ' est plus grand que ',
      '<': ' est plus petit que ',
      'minus': ' moins ',
      'point': ' virgule ',
      'blank': 'quoi',
    },
  };

  /// Fraction denominators spoken as words. "1/5" in a fractions lesson is
  /// "one fifth", not "1 divided by 5" — reading it as division is actively
  /// wrong for the thing being taught.
  static const _fractionWords = <String, Map<int, List<String>>>{
    // denominator: [singular, plural]
    'en': {
      2: ['half', 'halves'],
      3: ['third', 'thirds'],
      4: ['quarter', 'quarters'],
      5: ['fifth', 'fifths'],
      6: ['sixth', 'sixths'],
      8: ['eighth', 'eighths'],
      10: ['tenth', 'tenths'],
      100: ['hundredth', 'hundredths'],
    },
    'fr': {
      2: ['demi', 'demis'],
      3: ['tiers', 'tiers'],
      4: ['quart', 'quarts'],
      5: ['cinquième', 'cinquièmes'],
      6: ['sixième', 'sixièmes'],
      8: ['huitième', 'huitièmes'],
      10: ['dixième', 'dixièmes'],
      100: ['centième', 'centièmes'],
    },
  };

  /// Emoji and pictographs — decorative in captions, gibberish when spoken.
  static final _emoji = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{1F900}-\u{1F9FF}]',
    unicode: true,
  );

  /// Speaks a fraction the way a teacher would, or null when there is no
  /// natural wording for that denominator.
  static String? _fraction(int top, int bottom, String lang) {
    if (lang == 'sw') {
      // Swahili keeps the general "part x out of y" form, which is clear and
      // avoids inventing ordinals a child will not have met.
      if (bottom == 2) return top == 1 ? 'nusu' : 'sehemu $top kwa 2';
      if (bottom == 4 && top == 1) return 'robo';
      return 'sehemu $top kwa $bottom';
    }
    final words = _fractionWords[lang]?[bottom];
    if (words == null) return null;
    final name = top == 1 ? words[0] : words[1];
    if (lang == 'fr') return top == 1 ? 'un $name' : '$top $name';
    return top == 1 ? 'one $name' : '$top $name';
  }

  /// Soften robotic / code-heavy text so TTS sounds like a friendly coach.
  ///
  /// [lang] matters: symbol names, decimal separators and fraction wording all
  /// differ, and the code-reading rules below are for the English Python
  /// lessons only.
  static String naturalize(String text, {String lang = 'en'}) {
    var t = text.trim();
    if (t.isEmpty) return t;
    final words = _symbolWords[lang] ?? _symbolWords['en']!;

    if (lang == 'en') {
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
      // Soften bossy imperatives for kids.
      t = t.replaceFirst(
        RegExp(r'^Type:\s*', caseSensitive: false),
        'Let us write: ',
      );
      t = t.replaceFirst(
        RegExp(r'^Solve\s+', caseSensitive: false),
        'Let us solve ',
      );
      t = t.replaceAll(
        RegExp(r'\bpress RUN\b', caseSensitive: false),
        'press the big run button',
      );
      t = t.replaceAll(RegExp(r'\bRUN\b'), 'run');
    }

    // A blank, or a trailing "= ?", means the sentence is a question with a
    // hole in it: "3 × 4 = ?" should land as "three times four equals what?"
    // with rising intonation, not a flat statement.
    final hasGap = RegExp(r'_{2,}|=\s*\?').hasMatch(t);

    // "= ?" is a blank in disguise; fill it before the symbol pass so the
    // engine does not read a bare question mark.
    t = t.replaceAll(RegExp(r'=\s*\?'), '= ${words['blank']}?');

    // Left alone, engines read "___" as a run of underscores or swallow it,
    // so the question arrives with a hole in it.
    t = t.replaceAll(RegExp(r'_{2,}'), words['blank']!);

    // Stray quotes are punctuation, not sound. English code samples have
    // already had their meaningful quotes spoken as the word "quote".
    t = t.replaceAll('"', ' ');

    // Fractions before any other number handling, so 1/5 is not turned into a
    // division first.
    t = t.replaceAllMapped(RegExp(r'(\d+)\s*/\s*(\d+)'), (m) {
      final top = int.parse(m[1]!);
      final bottom = int.parse(m[2]!);
      return _fraction(top, bottom, lang) ?? '${m[1]} / ${m[2]}';
    });

    // Decimals. French writes 0,7 — the comma must not be read as a list
    // separator, and the point must not be read as a full stop.
    t = t.replaceAllMapped(
      RegExp(r'(\d)[.,](\d)'),
      (m) => '${m[1]}${words['point']}${m[2]}',
    );

    // Arithmetic symbols, in the child's language.
    for (final entry in words.entries) {
      if (entry.key.length != 1) continue;
      t = t.replaceAll(entry.key, entry.value);
    }
    // Only a spaced or numeric hyphen is a minus; "non-living" is a word.
    t = t.replaceAllMapped(
      RegExp(r'(?<=\d)\s*-\s*(?=\d)'),
      (_) => words['minus']!,
    );

    // Decorative pictographs are not speech.
    t = t.replaceAll(_emoji, ' ');

    // Strip leftover symbols TTS mangles.
    t = t.replaceAll(RegExp(r'[{}();:]'), ', ');
    // Punctuation debris from the substitutions above ("Andika, print, , .").
    t = t.replaceAll(RegExp(r'(\s*,)+(\s*[,.?!])'), r'$2');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Leading/trailing separators left behind by the substitutions above.
    t = t.replaceAll(RegExp(r'^[,\s]+'), '');
    t = t.replaceAll(RegExp(r'[,\s]+$'), '');
    if (t.isEmpty) return t;

    // Ensure terminal punctuation so the engine doesn't trail off flatly, and
    // let a gapped sentence end as the question it is.
    if (!RegExp(r'[.!?…]$').hasMatch(t)) {
      t = hasGap ? '$t?' : '$t.';
    } else if (hasGap) {
      t = t.replaceFirst(RegExp(r'\.$'), '?');
    }
    // Light spacing after commas/colons helps some engines — but never
    // between digits, which would split a decimal into two numbers.
    t = t.replaceAllMapped(
      RegExp(r'([,;:])(?!\s)(?![0-9])(\S)'),
      (m) => '${m[1]} ${m[2]}',
    );
    return t;
  }

  /// Split into speakable chunks (sentences) so long prompts get natural pauses.
  static List<String> chunkForSpeech(String text, {String lang = 'en'}) {
    final t = naturalize(text, lang: lang);
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

      final chunks = chunkForSpeech(text, lang: langCode);
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
