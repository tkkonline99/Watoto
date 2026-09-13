import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../analytics/analytics.dart';
import '../offline/offline_providers.dart';

/// Spoken narration for audio-first bands. Wraps [FlutterTts] with:
/// - the most natural voice the device reports, preferring offline ones
/// - a pace just under normal, set correctly for each platform
/// - one utterance per passage, so the voice flows instead of restarting
///   at every sentence
/// - a newer line cleanly replacing an older one, never interleaving with it
///
/// Every engine call is guarded: missing TTS / tests degrade to silence.
class NarrationController extends Notifier<bool> {
  FlutterTts? _tts;
  bool _configured = false;
  String? _langReady;
  final Map<String, Map<String, String>> _preferredVoice = {};

  /// Bumped by every [speak] and [stop]. A sequence that finds it changed has
  /// been replaced and must not say another word.
  ///
  /// Without it, a passage still being read would carry on after a new line
  /// started: Android and Windows answer an interrupted `speak` call as if it
  /// had finished, so the old loop went on to its next sentence and talked
  /// over the new one.
  int _generation = 0;
  Completer<void> _replaced = Completer<void>();

  void _replaceCurrent() {
    _generation++;
    if (!_replaced.isCompleted) _replaced.complete();
    _replaced = Completer<void>();
  }

  /// Resolved engine locale per app language, or null when this device has no
  /// voice for it. Populated on first speak; `containsKey` distinguishes
  /// "not probed yet" from "probed, nothing there".
  final Map<String, String?> _resolvedLocale = {};

  /// Languages we have already reported as unavailable, so the parent notice
  /// and the analytics event fire once per session rather than per sentence.
  final Set<String> _reportedMissing = {};

  @override
  bool build() => ref.watch(offlineStoreProvider).narrationEnabled;

  static const _locale = {'en': 'en-US', 'sw': 'sw-KE', 'fr': 'fr-FR'};

  /// Locales to try, best first, before giving up on a language.
  ///
  /// The old code set `sw-KE` and assumed it worked. Almost no Android device
  /// and no iOS device ships a Swahili voice, so on a real phone the engine
  /// either refused the call or kept the previous (English) voice and read
  /// Swahili sentences with English phonetics. Both outcomes were invisible
  /// from the code — nothing checked, nothing reported.
  static const localeChain = <String, List<String>>{
    'en': ['en-US', 'en-GB', 'en-KE', 'en-ZA', 'en'],
    'sw': ['sw-KE', 'sw-TZ', 'sw'],
    'fr': ['fr-FR', 'fr-CA', 'fr-BE', 'fr'],
  };

  /// Speaking pace per language, as a fraction of the voice's normal speed:
  /// a touch under normal so young listeners can follow, and a little slower
  /// again for French and Swahili, which stock voices tend to run together.
  static double _paceFor(String lang) => switch (lang) {
        'fr' => 0.88,
        'sw' => 0.85,
        _ => 0.9,
      };

  /// The voice's own pitch. Shifting the pitch of a neural or "natural" voice
  /// is what makes it sound processed; the styles move it only a little.
  static const double _pitch = 1.0;

  /// Converts a [pace] (1.0 = the voice's normal speed) into the value
  /// `flutter_tts` expects on [platform].
  ///
  /// The plugin hands the number to each platform unchanged, and they do not
  /// agree on what it means: AVSpeech (iOS) treats 0.5 as normal, Android and
  /// the Web Speech API treat 1.0 as normal, and the Windows plugin adds 0.5
  /// before WinRT, where 1.0 is normal. The old fixed 0.40 was a gentle pace
  /// on iOS and Windows — and 40% speed, every word stretched, on Android and
  /// in the browser.
  static double engineRate(
    double pace, {
    required TargetPlatform platform,
    required bool isWeb,
  }) {
    if (isWeb) return pace;
    return switch (platform) {
      TargetPlatform.iOS => (pace * 0.5).clamp(0.0, 1.0),
      TargetPlatform.windows => (pace - 0.5).clamp(0.0, 1.5),
      _ => pace,
    };
  }

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

  /// Picks the engine locale to use for [langCode] given what the device
  /// actually offers, or null when nothing matches.
  ///
  /// Pure and separately tested: matching is the part that was wrong, and it
  /// should not need a TTS engine to verify.
  ///
  /// [available] is whatever the engine reports — tags vary wildly in case and
  /// separator (`sw_KE`, `sw-ke`, `swa`), so comparison is normalised and a
  /// bare-language match counts.
  static String? resolveLocale(String langCode, Iterable<String> available) {
    String norm(String s) => s.toLowerCase().replaceAll('_', '-').trim();
    final have = available.map(norm).toSet();
    if (have.isEmpty) return null;

    final chain = localeChain[langCode] ?? [_locale[langCode] ?? langCode];
    // Exact match on the preferred chain first.
    for (final tag in chain) {
      if (have.contains(norm(tag))) return tag;
    }
    // Then any locale of the right language ("sw-UG" we did not think to list).
    final prefix = '${norm(langCode)}-';
    for (final tag in have) {
      if (tag == norm(langCode) || tag.startsWith(prefix)) return tag;
    }
    return null;
  }

  /// Engine locales this device reports, normalised. Empty when the engine is
  /// missing or refuses to enumerate (tests, some desktop shells).
  Future<List<String>> _deviceLocales(FlutterTts tts) async {
    try {
      final raw = await tts.getLanguages;
      if (raw is List) return [for (final l in raw) '$l'];
    } catch (_) {
      // Enumeration unsupported.
    }
    return const [];
  }

  /// Whether this device can speak [langCode] at all. Cached after the first
  /// probe; null result means "no voice installed for this language".
  Future<String?> resolvedLocaleFor(String langCode) async {
    if (_resolvedLocale.containsKey(langCode)) return _resolvedLocale[langCode];
    String? resolved;
    try {
      final tts = await _engine();
      final locales = await _deviceLocales(tts);
      if (locales.isEmpty) {
        // Engine cannot enumerate. Trust the preferred tag rather than going
        // silent on a device that may well be fine.
        resolved = _locale[langCode] ?? 'en-US';
      } else {
        resolved = resolveLocale(langCode, locales);
      }
    } catch (_) {
      resolved = null;
    }
    _resolvedLocale[langCode] = resolved;
    return resolved;
  }

  /// True once we know this device has no voice for [langCode]. Drives the
  /// parent-facing notice; captions carry the lesson either way.
  bool isKnownUnavailable(String langCode) =>
      _resolvedLocale.containsKey(langCode) && _resolvedLocale[langCode] == null;

  /// How natural a voice is likely to sound, from what the platform reports.
  ///
  /// Names alone miss most of it — Android calls its voices
  /// `en-us-x-tpc-local`, iOS calls them "Samantha" — so the quality, gender,
  /// network and install fields count too. An online-only voice is marked
  /// down hard: this app is used offline, and a network voice starts every
  /// line late and falls silent when the connection drops. One whose data is
  /// not downloaded cannot speak at all.
  static int voiceScore(Map<String, String> v) {
    final name = (v['name'] ?? v['voice'] ?? '').toLowerCase();
    final quality =
        (v['quality'] ?? '').toLowerCase().replaceAll(RegExp('[^a-z]'), '');
    var s = 0;
    if (name.contains('neural')) s += 50;
    if (name.contains('natural')) s += 45;
    if (name.contains('premium')) s += 40;
    if (name.contains('enhanced')) s += 35;
    if (name.contains('wavenet')) s += 35;
    if (name.contains('google')) s += 25;
    if (name.contains('samantha') ||
        name.contains('karen') ||
        name.contains('moira')) {
      s += 20; // friendly iOS system voices
    }
    s += switch (quality) {
      'premium' => 45,
      'veryhigh' => 40,
      'enhanced' => 35,
      'high' => 25,
      'low' || 'verylow' => -20,
      _ => 0,
    };
    if (v['network_required'] == '1') s -= 60;
    if ((v['features'] ?? '').contains('notInstalled')) s -= 200;
    if (v['gender'] == 'female' ||
        name.contains('female') ||
        name.contains('woman')) {
      s += 8;
    }
    if (name.contains('compact')) s -= 15;
    if (name.contains('eloquence')) s -= 5;
    return s;
  }

  /// The best of [voices] for [localeTag], or null when none speaks that
  /// language. A voice in the exact locale gets a head start so the accent
  /// matches the language the engine resolved, and ties go to the name that
  /// sorts first — the same device gets the same voice every time.
  static Map<String, String>? pickVoice(
    List<Map<String, String>> voices,
    String localeTag,
  ) {
    String loc(Map<String, String> v) =>
        (v['locale'] ?? v['localeId'] ?? '').toLowerCase().replaceAll('_', '-');
    final tag = localeTag.toLowerCase().replaceAll('_', '-');
    final lang = tag.split('-').first;
    final candidates = voices.where((v) {
      final l = loc(v);
      return l == lang || l.startsWith('$lang-');
    }).toList();
    if (candidates.isEmpty) return null;
    int total(Map<String, String> v) =>
        voiceScore(v) + (loc(v) == tag ? 30 : 0);
    candidates.sort((a, b) {
      final byScore = total(b).compareTo(total(a));
      return byScore != 0
          ? byScore
          : (a['name'] ?? '').compareTo(b['name'] ?? '');
    });
    return candidates.first;
  }

  /// Loads the language and the best voice for it.
  Future<void> _ensureVoice(FlutterTts tts, String langCode) async {
    final localeTag =
        _resolvedLocale[langCode] ?? _locale[langCode] ?? 'en-US';
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
        final best = pickVoice(voices, localeTag);
        if (best != null) {
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
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}\u{20E3}]',
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

  /// Longest passage handed to the engine as a single utterance.
  ///
  /// One utterance is what sounds smooth: the engine carries its intonation
  /// across the sentences and pauses at each full stop by itself. Speaking
  /// every sentence as its own call restarted the voice each time — flat
  /// again at every sentence start, with a warm-up on Android and a fixed
  /// 280 ms gap on top. The cap exists only for long story pages, since a
  /// browser can stall an utterance after about 15 seconds of speech.
  static const int maxUtteranceChars = 220;

  /// Splits [text] into utterances: whole sentences, joined up to
  /// [maxUtteranceChars]. A sentence is never cut in the middle, even one
  /// longer than the cap.
  static List<String> chunkForSpeech(String text, {String lang = 'en'}) {
    final t = naturalize(text, lang: lang);
    final sentences = t
        .split(RegExp(r'(?<=[.!?…])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    final out = <String>[];
    final buf = StringBuffer();
    for (final s in sentences) {
      if (buf.isNotEmpty && buf.length + 1 + s.length > maxUtteranceChars) {
        out.add(buf.toString());
        buf.clear();
      }
      if (buf.isNotEmpty) buf.write(' ');
      buf.write(s);
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }

  /// Speaks [text] in [langCode] when narration is on. Never throws.
  ///
  /// Starting a line replaces whatever was being said. The returned future
  /// completes when the line has been spoken, when a newer line or [stop]
  /// replaces it, or at once when there is nothing to say — so a caller can
  /// wait for the child to have heard it. [style] nudges pace and pitch.
  Future<void> speak(
    String text,
    String langCode, {
    SpeakStyle style = SpeakStyle.lesson,
  }) async {
    if (!state || text.trim().isEmpty) return;
    _replaceCurrent();
    final generation = _generation;
    final replaced = _replaced.future;
    bool isCurrent() => generation == _generation;
    try {
      final resolved = await resolvedLocaleFor(langCode);
      if (!isCurrent()) return;
      if (resolved == null) {
        // No voice for this language on this device. Speaking the text with
        // whatever voice happens to be loaded reads Swahili with English
        // phonetics — worse than silence, and it hides the problem. Captions
        // already carry every word.
        _reportMissingVoice(langCode);
        return;
      }
      final tts = await _engine();
      await tts.stop();
      if (!isCurrent()) return;
      await _ensureVoice(tts, langCode);

      var pace = _paceFor(langCode);
      var pitch = _pitch;
      switch (style) {
        case SpeakStyle.cheer:
          pace *= 1.05;
          pitch = 1.05;
        case SpeakStyle.hint:
          pace *= 0.93;
          pitch = 0.98;
        case SpeakStyle.lesson:
          break;
      }
      await tts.setSpeechRate(
        engineRate(pace, platform: defaultTargetPlatform, isWeb: kIsWeb),
      );
      await tts.setPitch(pitch);

      for (final utterance in chunkForSpeech(text, lang: langCode)) {
        if (!state || !isCurrent()) break;
        // Raced against replacement: a browser never answers the `speak` call
        // for an utterance that was cancelled, which would leave this waiting
        // for ever.
        await Future.any<void>([tts.speak(utterance).then((_) {}), replaced]);
      }
    } catch (_) {
      // No TTS engine available (desktop/test) — degrade to silent captions.
    }
  }

  /// Records a missing voice once per language per session.
  void _reportMissingVoice(String langCode) {
    if (!_reportedMissing.add(langCode)) return;
    // A silent audio-first band is a product emergency, not a detail — this is
    // the event that tells us how many families are affected.
    ref.read(analyticsProvider).log(AnalyticsEvents.narrationUnavailable, {
      'language': langCode,
    });
  }

  /// Languages found to have no voice on this device, for the Parent Zone.
  Set<String> get unavailableLanguages => {
        for (final e in _resolvedLocale.entries)
          if (e.value == null) e.key,
      };

  Future<void> stop() async {
    _replaceCurrent();
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
