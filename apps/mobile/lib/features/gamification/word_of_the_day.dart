import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/narration.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../domain/rules/review.dart';
import '../library/library_models.dart';
import '../library/library_repository.dart';

/// A single trilingual vocabulary card in the "Savanna Word of the Day" bridge.
class SavannaWordEntry {
  const SavannaWordEntry({
    required this.id,
    required this.emoji,
    required this.en,
    required this.sw,
    required this.fr,
    required this.hintEn,
    required this.hintSw,
    required this.hintFr,
  });

  final String id;
  final String emoji;
  final String en;
  final String sw;
  final String fr;
  final String hintEn;
  final String hintSw;
  final String hintFr;

  String hintFor(String locale) {
    switch (locale) {
      case 'sw':
        return hintSw;
      case 'fr':
        return hintFr;
      default:
        return hintEn;
    }
  }
}

/// Curated 14-word Savanna vocabulary deck spanning animals, nature, kindness,
/// and family across English, Kiswahili, and French.
const List<SavannaWordEntry> kSavannaWordDeck = <SavannaWordEntry>[
  SavannaWordEntry(
    id: 'lion',
    emoji: '🦁',
    en: 'Lion',
    sw: 'Simba',
    fr: 'Lion',
    hintEn: 'King of the sunny grassland',
    hintSw: 'Mfalme wa mbuga ya jua',
    hintFr: 'Roi de la savane ensoleillée',
  ),
  SavannaWordEntry(
    id: 'giraffe',
    emoji: '🦒',
    en: 'Giraffe',
    sw: 'Twiga',
    fr: 'Girafe',
    hintEn: 'Reaches the tallest acacia leaves',
    hintSw: 'Hufikia majani marefu ya mti',
    hintFr: 'Atteint les plus hautes feuilles',
  ),
  SavannaWordEntry(
    id: 'elephant',
    emoji: '🐘',
    en: 'Elephant',
    sw: 'Tembo',
    fr: 'Éléphant',
    hintEn: 'Gentle giant who never forgets',
    hintSw: 'Rafiki mkubwa mwenye kumbukumbu',
    hintFr: 'Doux géant à la grande mémoire',
  ),
  SavannaWordEntry(
    id: 'friend',
    emoji: '🤝',
    en: 'Friend',
    sw: 'Rafiki',
    fr: 'Ami',
    hintEn: 'Someone who shares and helps you smile',
    hintSw: 'Mtu anayeshirikiana na kukufurahisha',
    hintFr: 'Quelqu’un qui partage et fait sourire',
  ),
  SavannaWordEntry(
    id: 'star',
    emoji: '⭐',
    en: 'Star',
    sw: 'Nyota',
    fr: 'Étoile',
    hintEn: 'Shines bright in the night sky',
    hintSw: 'Inang’aa angani wakati wa usiku',
    hintFr: 'Brille dans le ciel nocturne',
  ),
  SavannaWordEntry(
    id: 'sun',
    emoji: '☀️',
    en: 'Sun',
    sw: 'Jua',
    fr: 'Soleil',
    hintEn: 'Warms the savanna every morning',
    hintSw: 'Huangaza mbuga kila asubuhi',
    hintFr: 'Réchauffe la savane chaque matin',
  ),
  SavannaWordEntry(
    id: 'water',
    emoji: '💧',
    en: 'Water',
    sw: 'Maji',
    fr: 'Eau',
    hintEn: 'Cool drink at the river oasis',
    hintSw: 'Kinywaji baridi kwenye mto',
    hintFr: 'Boisson fraîche à la rivière',
  ),
  SavannaWordEntry(
    id: 'tree',
    emoji: '🌳',
    en: 'Tree',
    sw: 'Mti',
    fr: 'Arbre',
    hintEn: 'Gives cool shade for story time',
    hintSw: 'Hutoa kivuli kizuri cha hadithi',
    hintFr: 'Donne de l’ombre pour les histoires',
  ),
  SavannaWordEntry(
    id: 'zebra',
    emoji: '🦓',
    en: 'Zebra',
    sw: 'Punda Milia',
    fr: 'Zèbre',
    hintEn: 'Gallops with black and white stripes',
    hintSw: 'Hukimbia na mistari meusi na meupe',
    hintFr: 'Galope avec des rayures noires et blanches',
  ),
  SavannaWordEntry(
    id: 'thank_you',
    emoji: '🙏',
    en: 'Thank You',
    sw: 'Asante',
    fr: 'Merci',
    hintEn: 'Kind words that warm every heart',
    hintSw: 'Neno la heshima na shukrani',
    hintFr: 'Un mot doux qui réchauffe le cœur',
  ),
  SavannaWordEntry(
    id: 'book',
    emoji: '📖',
    en: 'Book',
    sw: 'Kitabu',
    fr: 'Livre',
    hintEn: 'Opens a world of stories and wonder',
    hintSw: 'Hufungua ulimwengu wa hadithi',
    hintFr: 'Ouvre un monde d’histoires',
  ),
  SavannaWordEntry(
    id: 'song',
    emoji: '🎵',
    en: 'Song',
    sw: 'Wimbo',
    fr: 'Chanson',
    hintEn: 'Makes the whole village dance together',
    hintSw: 'Hufanya kijiji kizima kucheza pamoja',
    hintFr: 'Fait danser tout le village',
  ),
  SavannaWordEntry(
    id: 'bird',
    emoji: '🦜',
    en: 'Bird',
    sw: 'Ndege',
    fr: 'Oiseau',
    hintEn: 'Sings from the baobab branches',
    hintSw: 'Huimba juu ya matawi ya mbuyu',
    hintFr: 'Chante sur les branches du baobab',
  ),
  SavannaWordEntry(
    id: 'heart',
    emoji: '💛',
    en: 'Love',
    sw: 'Upendo',
    fr: 'Amour',
    hintEn: 'Caring for family and friends',
    hintSw: 'Kuwajali familia na marafiki',
    hintFr: 'Prendre soin de sa famille et ses amis',
  ),
];

/// Deterministically selects the Savanna Word of the Day for [date], optionally
/// shifted by [offset] when a child cycles through extra words.
SavannaWordEntry wordOfTheDayFor(DateTime date, {int offset = 0}) {
  final dayNumber =
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
          const Duration(days: 1).inMilliseconds;
  final idx = (dayNumber + offset).abs() % kSavannaWordDeck.length;
  return kSavannaWordDeck[idx];
}

/// Interactive trilingual "Savanna Word of the Day" card (`EN ↔ SW ↔ FR`).
/// Tapping any of the 3 language pills speaks the word aloud in that language.
class SavannaWordOfTheDayCard extends ConsumerStatefulWidget {
  const SavannaWordOfTheDayCard({
    super.key,
    required this.locale,
    this.date,
  });

  final String locale;
  final DateTime? date;

  @override
  ConsumerState<SavannaWordOfTheDayCard> createState() =>
      _SavannaWordOfTheDayCardState();
}

class _SavannaWordOfTheDayCardState
    extends ConsumerState<SavannaWordOfTheDayCard> {
  int _offset = 0;
  String? _activeLang;

  Future<void> _speakWord(String lang, String word) async {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _activeLang = lang);
    await ref.read(narrationProvider.notifier).speak(
          word,
          lang,
          style: SpeakStyle.cheer,
        );
  }

  @override
  Widget build(BuildContext context) {
    final entry = wordOfTheDayFor(
      widget.date ?? DateTime.now(),
      offset: _offset,
    );
    final header = switch (widget.locale) {
      'sw' => 'NENO LA LEO • LUGHA 3',
      'fr' => 'MOT DU JOUR • 3 LANGUES',
      _ => 'WORD OF THE DAY • 3 LANGUAGES',
    };

    return ExcludeSemantics(
      child: Container(
        key: const ValueKey('word-of-the-day-card'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFBF0), Color(0xFFFFF1CC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: WatotoColors.sun.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(entry.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: header,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                            color: WatotoColors.mango,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          text: entry.hintFor(widget.locale),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: WatotoColors.deep.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  key: const ValueKey('wotd-next-button'),
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    setState(() {
                      _offset = (_offset + 1) % kSavannaWordDeck.length;
                      _activeLang = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: WatotoColors.mango.withValues(alpha: 0.35),
                      ),
                    ),
                    child: RichText(
                      text: const TextSpan(
                        text: '↻',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: WatotoColors.deep,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _LangWordPill(
                    pillKey: const ValueKey('wotd-speak-en'),
                    flag: '🇬🇧',
                    langLabel: 'EN',
                    word: entry.en,
                    active: _activeLang == 'en',
                    onTap: () => _speakWord('en', entry.en),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LangWordPill(
                    pillKey: const ValueKey('wotd-speak-sw'),
                    flag: '🇰🇪',
                    langLabel: 'SW',
                    word: entry.sw,
                    active: _activeLang == 'sw',
                    onTap: () => _speakWord('sw', entry.sw),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LangWordPill(
                    pillKey: const ValueKey('wotd-speak-fr'),
                    flag: '🇫🇷',
                    langLabel: 'FR',
                    word: entry.fr,
                    active: _activeLang == 'fr',
                    onTap: () => _speakWord('fr', entry.fr),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LangWordPill extends StatelessWidget {
  const _LangWordPill({
    required this.pillKey,
    required this.flag,
    required this.langLabel,
    required this.word,
    required this.active,
    required this.onTap,
  });

  final Key pillKey;
  final String flag;
  final String langLabel;
  final String word;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? WatotoColors.mango : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: pillKey,
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? WatotoColors.mango
                  : WatotoColors.deep.withValues(alpha: 0.16),
              width: 1.4,
            ),
          ),
          child: Column(
            children: [
              RichText(
                text: TextSpan(
                  text: '$flag $langLabel 🔊',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? Colors.white
                        : WatotoColors.deep.withValues(alpha: 0.65),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  text: word,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : WatotoColors.deep,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recommendation returned by [resolveMemoryBoostForChild] when a child has
/// previously retried or scored shaky on a specific activity (or has a due
/// spaced-repetition item).
class MemoryBoostRecommendation {
  const MemoryBoostRecommendation({
    required this.item,
    required this.record,
    required this.bonusCoins,
  });

  final LibraryItem item;
  final ReviewRecord record;
  final int bonusCoins;
}

/// Inspects the child's spaced-repetition review records to find the highest
/// priority activity that needed retries (`retries > 0`), had shaky mastery
/// (`mastery == MasteryLevel.shaky`), or is due for review.
MemoryBoostRecommendation? resolveMemoryBoostForChild({
  required String childId,
  required OfflineStore store,
  required LibraryRepository library,
  DateTime? now,
}) {
  if (childId.isEmpty) return null;
  final records = store.reviewRecords(childId);
  if (records.isEmpty) return null;
  final when = now ?? DateTime.now();

  final candidates = records.where((ReviewRecord rec) {
    return rec.retries > 0 ||
        rec.mastery == MasteryLevel.shaky ||
        rec.isDue(when);
  }).toList();
  if (candidates.isEmpty) return null;

  candidates.sort((ReviewRecord a, ReviewRecord b) {
    final shakyA = a.mastery == MasteryLevel.shaky ? 0 : 1;
    final shakyB = b.mastery == MasteryLevel.shaky ? 0 : 1;
    if (shakyA != shakyB) return shakyA.compareTo(shakyB);
    final byRetries = b.retries.compareTo(a.retries);
    if (byRetries != 0) return byRetries;
    return a.lastScore.compareTo(b.lastScore);
  });

  for (final rec in candidates) {
    final item = library.byId[rec.itemId];
    if (item != null) {
      return MemoryBoostRecommendation(
        item: item,
        record: rec,
        bonusCoins: 5,
      );
    }
  }
  return null;
}

/// Card shown on `ChildHomeScreen` when [resolveMemoryBoostForChild] finds an
/// activity the child previously struggled with or is due to revisit.
class KiboMemoryBoostCard extends StatelessWidget {
  const KiboMemoryBoostCard({
    super.key,
    required this.recommendation,
    required this.locale,
    required this.onLaunch,
  });

  final MemoryBoostRecommendation recommendation;
  final String locale;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final badge = switch (locale) {
      'sw' => 'KUMBUKUMBU YA KIBO • +${recommendation.bonusCoins} SARAFU',
      'fr' => 'DÉFI MÉMOIRE DE KIBO • +${recommendation.bonusCoins} PIÈCES',
      _ => 'KIBO’S MEMORY BOOST • +${recommendation.bonusCoins} COINS',
    };
    final title = recommendation.item.title;

    return ExcludeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('kibo-memory-boost-card'),
          borderRadius: BorderRadius.circular(20),
          onTap: onLaunch,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEDF7F6), Color(0xFFD6F0EC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: WatotoColors.leaf.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: WatotoColors.leaf.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('🧠', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: badge,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: WatotoColors.leaf,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          text: title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: WatotoColors.deep,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.bolt_rounded,
                  color: WatotoColors.leaf,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
