import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../domain/rules/review.dart';
import '../offline/offline_providers.dart';

/// Optional HTTPS endpoint for cloud-assisted AI generation when parent
/// consent (`consent.aiFeatures`) is enabled.
const String kWatotoAiEndpoint = String.fromEnvironment('WATOTO_AI_URL');

/// Guided, child-safe curiosity modes for "Ask Kibo" (never open free-text).
enum AiCuriosityKind {
  simpler,
  clue,
  funFact,
  trilingualBridge,
}

/// A single Socratic response from Kibo.
class AiSocraticReply {
  const AiSocraticReply({
    required this.kind,
    required this.headline,
    required this.body,
    required this.locale,
    required this.fromCloud,
  });

  final AiCuriosityKind kind;
  final String headline;
  final String body;
  final String locale;
  final bool fromCloud;
}

/// Hero tile options for Kibo's AI Story Weaver.
enum StoryHero {
  lion('lion', '🦁', 'Simba', 'Simba', 'Simba'),
  giraffe('giraffe', '🦒', 'Twiga', 'Twiga', 'Twiga'),
  elephant('elephant', '🐘', 'Tembo', 'Tembo', 'Tembo'),
  kibo('kibo', '🐵', 'Kibo', 'Kibo', 'Kibo');

  const StoryHero(this.id, this.emoji, this.en, this.sw, this.fr);
  final String id;
  final String emoji;
  final String en;
  final String sw;
  final String fr;

  String labelFor(String locale) => switch (locale) {
        'sw' => sw,
        'fr' => fr,
        _ => en,
      };
}

/// Place tile options for Kibo's AI Story Weaver.
enum StoryPlace {
  baobab('baobab', '🌳', 'Starry Baobab', 'Mbuyu wa Nyota', 'Baobab Étoilé'),
  oasis('oasis', '💧', 'River Oasis', 'Chemchemi ya Mto', 'Oasis de la Rivière'),
  market('market', '🥁', 'Village Market', 'Soko la Kijiji', 'Marché du Village'),
  hills('hills', '☀️', 'Sunny Hills', 'Vilima vya Jua', 'Collines Ensoleillées');

  const StoryPlace(this.id, this.emoji, this.en, this.sw, this.fr);
  final String id;
  final String emoji;
  final String en;
  final String sw;
  final String fr;

  String labelFor(String locale) => switch (locale) {
        'sw' => sw,
        'fr' => fr,
        _ => en,
      };
}

/// Learning theme tile options for Kibo's AI Story Weaver.
enum StoryTheme {
  sharing('sharing', '🤝', 'Kindness & Sharing', 'Wema na Kushirikiana',
      'Partage et Gentillesse'),
  counting('counting', '🔢', 'Counting Together', 'Kuhesabu Pamoja',
      'Compter Ensemble'),
  nature('nature', '🌱', 'Caring for Nature', 'Kutunza Mazingira',
      'Protéger la Nature'),
  bravery('bravery', '💛', 'Gentle Bravery', 'Ujasiri wa Upole',
      'Doux Courage');

  const StoryTheme(this.id, this.emoji, this.en, this.sw, this.fr);
  final String id;
  final String emoji;
  final String en;
  final String sw;
  final String fr;

  String labelFor(String locale) => switch (locale) {
        'sw' => sw,
        'fr' => fr,
        _ => en,
      };
}

/// A 3-page co-created story produced by Kibo's AI Story Weaver.
class WovenStory {
  const WovenStory({
    required this.title,
    required this.hero,
    required this.place,
    required this.theme,
    required this.pages,
    required this.questionPrompt,
    required this.options,
    required this.correctIndex,
    required this.locale,
  });

  final String title;
  final StoryHero hero;
  final StoryPlace place;
  final StoryTheme theme;
  final List<String> pages;
  final String questionPrompt;
  final List<String> options;
  final int correctIndex;
  final String locale;
}

/// Weekly AI Parent Coach synthesis for a child's learning profile.
class ParentCoachBriefing {
  const ParentCoachBriefing({
    required this.strengthSummary,
    required this.focusSummary,
    required this.focusSubject,
    required this.offlineActivities,
    required this.aiConsentEnabled,
  });

  final String strengthSummary;
  final String focusSummary;
  final String focusSubject;
  final List<String> offlineActivities;
  final bool aiConsentEnabled;
}

/// Strips any PII-shaped keys (`nickname`, `name`, `email`, `birthYear`,
/// `deviceId`, `childId`, `pin`, `password`) from an outbound AI payload so
/// zero personal data can ever leave the device (COPPA / GDPR-K / Apple Kids).
Map<String, Object?> sanitizeAiPayload(Map<String, Object?> raw) {
  const forbidden = <String>{
    'nickname',
    'name',
    'childname',
    'email',
    'birthyear',
    'dob',
    'deviceid',
    'childid',
    'pin',
    'password',
    'token',
  };
  final clean = <String, Object?>{};
  for (final entry in raw.entries) {
    final lower = entry.key.toLowerCase().replaceAll('_', '');
    if (forbidden.contains(lower)) continue;
    clean[entry.key] = entry.value;
  }
  return clean;
}

/// COPPA-safe hybrid AI engine for Watoto:
/// - Always works 100% offline with zero latency using a trilingual (`EN` /
///   `SW` / `FR`) pedagogical synthesizer.
/// - Only attempts optional HTTPS cloud enrichment when `store.consent.aiFeatures`
///   is explicitly enabled by the parent AND [endpoint] is configured, after
///   stripping all PII via [sanitizeAiPayload].
class WatotoAiEngine {
  WatotoAiEngine({
    required this.store,
    http.Client? httpClient,
    this.endpoint = kWatotoAiEndpoint,
  }) : _http = httpClient;

  final OfflineStore store;
  final http.Client? _http;
  final String endpoint;

  /// True when the parent has opted into AI learning features.
  bool get isAiConsentEnabled => store.consent.aiFeatures;

  /// Generates a Socratic response for [kind] tailored to [subject], [stage],
  /// [promptContext], and [locale] (`en`, `sw`, `fr`).
  Future<AiSocraticReply> generateSocraticResponse({
    required AiCuriosityKind kind,
    required String subject,
    required int stage,
    required String promptContext,
    required String locale,
  }) async {
    // 1. Optional cloud enrichment if parent consented and HTTPS endpoint is set.
    if (isAiConsentEnabled &&
        endpoint.startsWith('https://') &&
        _http != null) {
      try {
        final payload = sanitizeAiPayload(<String, Object?>{
          'kind': kind.name,
          'subject': subject,
          'stage': stage,
          'locale': locale,
          'promptContext': promptContext.length > 160
              ? promptContext.substring(0, 160)
              : promptContext,
        });
        final resp = await _http
            .post(
              Uri.parse(endpoint),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 3));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final body = data['body'] as String?;
          final headline = data['headline'] as String?;
          if (body != null && body.trim().isNotEmpty) {
            return AiSocraticReply(
              kind: kind,
              headline: headline ?? _headlineFor(kind, locale),
              body: body.trim(),
              locale: locale,
              fromCloud: true,
            );
          }
        }
      } catch (_) {
        // Fall through to deterministic on-device pedagogical synthesizer.
      }
    }

    // 2. Deterministic on-device pedagogical synthesizer (100% offline).
    return AiSocraticReply(
      kind: kind,
      headline: _headlineFor(kind, locale),
      body: _synthesizeSocraticBody(
        kind: kind,
        subject: subject,
        stage: stage,
        promptContext: promptContext,
        locale: locale,
      ),
      locale: locale,
      fromCloud: false,
    );
  }

  String _headlineFor(AiCuriosityKind kind, String locale) {
    return switch ((kind, locale)) {
      (AiCuriosityKind.simpler, 'sw') => '💡 Kibo Anaeleza kwa Urahisi',
      (AiCuriosityKind.simpler, 'fr') => '💡 Kibo Explique Simplement',
      (AiCuriosityKind.simpler, _) => '💡 Kibo Explains It Simply',
      (AiCuriosityKind.clue, 'sw') => '🧩 Kidokezo cha Kibo',
      (AiCuriosityKind.clue, 'fr') => '🧩 L’Indice de Kibo',
      (AiCuriosityKind.clue, _) => '🧩 Kibo’s Thinking Clue',
      (AiCuriosityKind.funFact, 'sw') => '🌍 Siri ya Mbuga ya Savanna',
      (AiCuriosityKind.funFact, 'fr') => '🌍 Secret de la Savane',
      (AiCuriosityKind.funFact, _) => '🌍 Savanna Discovery Fact',
      (AiCuriosityKind.trilingualBridge, 'sw') => '🗣️ Daraja la Lugha 3',
      (AiCuriosityKind.trilingualBridge, 'fr') => '🗣️ Pont des 3 Langues',
      (AiCuriosityKind.trilingualBridge, _) => '🗣️ 3-Language Savanna Bridge',
    };
  }

  String _synthesizeSocraticBody({
    required AiCuriosityKind kind,
    required String subject,
    required int stage,
    required String promptContext,
    required String locale,
  }) {
    final lowerSubj = subject.toLowerCase();
    final isMath = lowerSubj.contains('math') ||
        lowerSubj.contains('num') ||
        RegExp(r'\d').hasMatch(promptContext);
    final isScience = lowerSubj.contains('sci') ||
        lowerSubj.contains('nature') ||
        lowerSubj.contains('world');
    final isTech = lowerSubj.contains('tech') ||
        lowerSubj.contains('code') ||
        lowerSubj.contains('logic');

    switch (kind) {
      case AiCuriosityKind.simpler:
        if (locale == 'sw') {
          if (isMath) {
            return 'Chukua hatua moja baada ya nyingine! Hesabu kwa vidole vyako polepole kama Twiga anavyokula majani moja-moja.';
          }
          if (isScience) {
            return 'Fikiria unachokiona kila siku nje kwenye jua, maji, na miti. Kila kitu kwenye mbuga kina kazi yake!';
          }
          return 'Soma au sikiliza neno kuu kwanza. Kibo anakukumbusha: huna haraka, chagua picha au neno linalolingana zaidi!';
        }
        if (locale == 'fr') {
          if (isMath) {
            return 'Allons-y étape par étape ! Compte doucement sur tes doigts comme la girafe qui compte les feuilles.';
          }
          if (isScience) {
            return 'Imagine ce que tu vois dehors : le soleil, l’eau et les arbres. Chaque chose dans la nature a un rôle !';
          }
          return 'Écoute bien le mot principal. Prends ton temps et cherche l’image ou le son qui correspond le mieux !';
        }
        if (isMath) {
          return 'Let’s break it into tiny steps! Picture pebbles by the river and count them one by one on your fingers.';
        }
        if (isScience) {
          return 'Picture what happens outside in the sunny Savanna! Think about how water, plants, and animals help each other.';
        }
        if (isTech) {
          return 'Think like a builder! Which piece comes first in the pattern before the next step can run?';
        }
        return 'Let’s slow down and listen to the key word first. Picture the story in your head, then pick the choice that matches!';

      case AiCuriosityKind.clue:
        if (locale == 'sw') {
          return 'Jiulize: ni chaguo gani ambalo halifanani na mengine? Ondoa moja lisilo sahihi kwanza, kisha jaribu tena!';
        }
        if (locale == 'fr') {
          return 'Demande-toi : quelle réponse est différente des autres ? Écarte celle qui ne va pas, puis regarde bien ce qui reste !';
        }
        return 'Ask yourself: which choice clearly does NOT fit the picture or pattern? Rule out one tricky option first, then look closely at what remains!';

      case AiCuriosityKind.funFact:
        if (locale == 'sw') {
          if (isMath) {
            return 'Je, wajua? Punda milia kila mmoja ana mistari ya kipekee kama alama za vidole vyako!';
          }
          return 'Je, wajua? Mti wa Mbuyu (Baobab) unaweza kuhifadhi maelfu ya lita za maji ili kuwasaidia wanyama wakati wa kiangazi!';
        }
        if (locale == 'fr') {
          if (isMath) {
            return 'Le savais-tu ? Chaque zèbre de la savane possède des rayures uniques, comme tes empreintes digitales !';
          }
          return 'Le savais-tu ? Le grand arbre Baobab peut garder des milliers de litres d’eau dans son tronc pour aider la savane !';
        }
        if (isMath) {
          return 'Did you know? Every zebra in the Serengeti has its own unique pattern of stripes—just like your fingerprints!';
        }
        return 'Did you know? Elephants flap their giant ears to cool down and can hear a friend’s footsteps from miles away!';

      case AiCuriosityKind.trilingualBridge:
        if (isMath) {
          return '🇬🇧 Count (1, 2, 3)  •  🇰🇪 Hesabu (Moja, Mbili, Tatu)  •  🇫🇷 Compter (Un, Deux, Trois)';
        }
        if (isScience) {
          return '🇬🇧 Nature & Sun  •  🇰🇪 Mazingira na Jua  •  🇫🇷 La Nature et le Soleil';
        }
        return '🇬🇧 Let’s Learn Together!  •  🇰🇪 Tujifunze Pamoja!  •  🇫🇷 Apprenons Ensemble !';
    }
  }

  /// Co-creates a 3-page trilingual story (`en`, `sw`, `fr`) from the child's
  /// chosen [hero], [place], and [theme], complete with a comprehension check.
  WovenStory weaveCustomStory({
    required StoryHero hero,
    required StoryPlace place,
    required StoryTheme theme,
    required String locale,
  }) {
    final h = hero.labelFor(locale);
    final p = place.labelFor(locale);
    final t = theme.labelFor(locale);

    switch (locale) {
      case 'sw':
        final pages = <String>[
          'Asubuhi moja angavu, ${hero.emoji} $h alitembea hadi kwenye ${place.emoji} $p.',
          switch (theme) {
            StoryTheme.sharing =>
              'Huko kwenye $p, $h aligawana matunda matamu na marafiki zake wote kwa upendo.',
            StoryTheme.counting =>
              'Huko kwenye $p, $h alihesabu mawe matatu yanayong’aa: moja, mbili, tatu!',
            StoryTheme.nature =>
              'Huko kwenye $p, $h alimwagilia miche midogo maji safi ili ikue mirefu.',
            StoryTheme.bravery =>
              'Huko kwenye $p, $h alovuta pumzi ndefu na kumsaidia ndege mdogo kurudi kwenye kiota.',
          },
          'Kijiji chote kilishangilia kwa furaha! $h aligundua kuwa $t huleta tabasamu kwa kila mtu.',
        ];
        return WovenStory(
          title: '$h na $p',
          hero: hero,
          place: place,
          theme: theme,
          pages: pages,
          questionPrompt: 'Je, $h alienda wapi kwenye hadithi hii?',
          options: <String>[
            p,
            'Juu ya Mwezi',
            'Chini ya Bahari',
          ],
          correctIndex: 0,
          locale: locale,
        );

      case 'fr':
        final pages = <String>[
          'Un beau matin doré, ${hero.emoji} $h est parti explorer ${place.emoji} $p.',
          switch (theme) {
            StoryTheme.sharing =>
              'Près de $p, $h a partagé des fruits sucrés avec tous ses amis de la savane.',
            StoryTheme.counting =>
              'Près de $p, $h a compté trois étoiles brillantes : un, deux, trois !',
            StoryTheme.nature =>
              'Près de $p, $h a arrosé les jeunes fleurs pour protéger la belle nature.',
            StoryTheme.bravery =>
              'Près de $p, $h a pris une grande inspiration et a aidé un petit oiseau à retrouver son nid.',
          },
          'Toute la savane a applaudi de joie ! $h a appris que « $t » rend tout le monde heureux.',
        ];
        return WovenStory(
          title: '$h et $p',
          hero: hero,
          place: place,
          theme: theme,
          pages: pages,
          questionPrompt: 'Où $h est-il allé dans cette histoire ?',
          options: <String>[
            p,
            'Sur la Lune',
            'Sous l’Océan',
          ],
          correctIndex: 0,
          locale: locale,
        );

      default:
        final pages = <String>[
          'One golden morning, ${hero.emoji} $h set off on an adventure to the ${place.emoji} $p.',
          switch (theme) {
            StoryTheme.sharing =>
              'At the $p, $h shared sweet savanna berries so every friend had enough to eat.',
            StoryTheme.counting =>
              'At the $p, $h counted three sparkling river stones out loud: one, two, three!',
            StoryTheme.nature =>
              'At the $p, $h gently watered the young acacia sprouts to keep the savanna green.',
            StoryTheme.bravery =>
              'At the $p, $h took a calm, brave breath and helped a little weaver bird find its nest.',
          },
          'All the animals cheered together! $h learned that $t makes the whole savanna shine.',
        ];
        return WovenStory(
          title: '$h at the $p',
          hero: hero,
          place: place,
          theme: theme,
          pages: pages,
          questionPrompt: 'Where did $h go on this adventure?',
          options: <String>[
            p,
            'To the icy North Pole',
            'Deep under the ocean',
          ],
          correctIndex: 0,
          locale: locale,
        );
    }
  }

  /// Synthesizes a weekly AI Parent Coach briefing and 3 screen-free family
  /// activities for [childId] based on their on-device mastery & retry records.
  ParentCoachBriefing generateParentCoachBriefing({
    required String childId,
    required String nickname,
    required String locale,
  }) {
    final records = store.reviewRecords(childId);
    final lessonsDone = store.completedLessonCount(childId);
    final streak = store.streakFor(childId);

    ReviewRecord? weakest;
    ReviewRecord? strongest;
    for (final r in records) {
      if (weakest == null ||
          r.retries > weakest.retries ||
          r.lastScore < weakest.lastScore) {
        weakest = r;
      }
      if (strongest == null || r.lastScore > strongest.lastScore) {
        strongest = r;
      }
    }

    final focusSubj = (weakest?.subject.isNotEmpty ?? false)
        ? weakest!.subject
        : 'Literacy & Numeracy';
    final strongSubj = (strongest?.subject.isNotEmpty ?? false)
        ? strongest!.subject
        : 'Savanna Stories';

    switch (locale) {
      case 'sw':
        final strength = lessonsDone > 0
            ? '🌟 Nguvu: $nickname amekamilisha masomo $lessonsDone (mfululizo wa siku $streak) na anaonyesha umahiri mzuri kwenye $strongSubj.'
            : '🌟 Nguvu: $nickname yuko tayari kuanza safari ya kujifunza kwa sauti na michezo!';
        final focus = weakest != null &&
                (weakest.retries > 0 || weakest.mastery == MasteryLevel.shaky)
            ? '🎯 Eneo la Kukua: $nickname alihitaji majaribio ya ziada kwenye $focusSubj. Mazoezi mafupi ya dakika 3 nyumbani yatasaidia sana!'
            : '🎯 Eneo la Kukua: Endelea kuchunguza mada mpya za $focusSubj hatua kwa hatua.';
        return ParentCoachBriefing(
          strengthSummary: strength,
          focusSummary: focus,
          focusSubject: focusSubj,
          offlineActivities: _offlineGamesFor(focusSubj, 'sw'),
          aiConsentEnabled: isAiConsentEnabled,
        );

      case 'fr':
        final strength = lessonsDone > 0
            ? '🌟 Point fort : $nickname a terminé $lessonsDone leçons (série de $streak jours) avec une belle assurance en $strongSubj.'
            : '🌟 Point fort : $nickname est prêt à découvrir ses premières leçons interactives !';
        final focus = weakest != null &&
                (weakest.retries > 0 || weakest.mastery == MasteryLevel.shaky)
            ? '🎯 Piste de progrès : $nickname a eu besoin de plusieurs essais en $focusSubj. Un petit jeu de 3 minutes hors écran l’aidera !'
            : '🎯 Piste de progrès : Continuez à explorer $focusSubj avec des questions ludiques.';
        return ParentCoachBriefing(
          strengthSummary: strength,
          focusSummary: focus,
          focusSubject: focusSubj,
          offlineActivities: _offlineGamesFor(focusSubj, 'fr'),
          aiConsentEnabled: isAiConsentEnabled,
        );

      default:
        final strength = lessonsDone > 0
            ? '🌟 Strength: $nickname has completed $lessonsDone lessons ($streak-day streak) and shows strong confidence in $strongSubj.'
            : '🌟 Strength: $nickname is ready to start exploring interactive Savanna lessons!';
        final focus = weakest != null &&
                (weakest.retries > 0 || weakest.mastery == MasteryLevel.shaky)
            ? '🎯 Growth Focus: $nickname needed extra retries in $focusSubj. A playful 3-minute offline game together will lock this concept in!'
            : '🎯 Growth Focus: Keep building momentum in $focusSubj with short, joyful daily practice.';
        return ParentCoachBriefing(
          strengthSummary: strength,
          focusSummary: focus,
          focusSubject: focusSubj,
          offlineActivities: _offlineGamesFor(focusSubj, 'en'),
          aiConsentEnabled: isAiConsentEnabled,
        );
    }
  }

  List<String> _offlineGamesFor(String subject, String locale) {
    final s = subject.toLowerCase();
    final isMath = s.contains('math') || s.contains('num');
    final isSci = s.contains('sci') || s.contains('nature');

    if (locale == 'sw') {
      if (isMath) {
        return const <String>[
          '🍽️ Hesabu vijiko na sahani mezani kabla ya chakula (1 hadi 10).',
          '👏 Piga makofi kwa mpangilio (2-1-2) na mtoto arudie mdundo huo.',
          '🧺 Panga matunda au vitu vya kuchezea kulingana na ukubwa na rangi.',
        ];
      }
      if (isSci) {
        return const <String>[
          '🌱 Chunguza jani au ua nje na mzungumzie jinsi mimea inavyokunywa maji.',
          '☁️ Tazama mawingu angani na uulize: "Je, linaonekana kama mnyama gani?"',
          '💧 Jaribu vitu viwili kwenye bakuli la maji: kipi kinaelea na kipi kinazama?',
        ];
      }
      return const <String>[
        '🗣️ Mchezo wa Sauti: Taja vitu 3 chumbani vinavyoanza na sauti ya herufi "S".',
        '📖 Muulize mtoto asimulie upya hadithi ya leo kwa maneno yake mwenyewe.',
        '🌍 Taja neno moja (kama "Simba" au "Maji") kwa Kiingereza, Kiswahili na Kifaransa!',
      ];
    }

    if (locale == 'fr') {
      if (isMath) {
        return const <String>[
          '🍽️ Comptez les cuillères et les assiettes ensemble avant le repas.',
          '👏 Frappez un rythme dans vos mains (2-1-2) et laissez l’enfant le répéter.',
          '🧺 Triez des fruits ou des jouets du plus petit au plus grand.',
        ];
      }
      if (isSci) {
        return const <String>[
          '🌱 Observez une feuille dehors et expliquez comment la plante boit l’eau.',
          '☁️ Regardez les nuages et devinez à quel animal de la savane ils ressemblent.',
          '💧 Testez dans un bol d’eau : quel objet flotte et quel objet coule ?',
        ];
      }
      return const <String>[
        '🗣️ Chasse aux sons : trouvez 3 objets autour de vous qui commencent par « S ».',
        '📖 Demandez à votre enfant de raconter l’histoire du jour avec ses propres mots.',
        '🌍 Dites le mot du jour ensemble en anglais, kiswahili et français !',
      ];
    }

    if (isMath) {
      return const <String>[
        '🍽️ Kitchen Table Count: Count spoons and cups together while setting the table.',
        '👏 Rhythm Pattern Clap: Clap a 2-1-2 beat and invite your child to echo it back.',
        '🧺 Shape & Size Sort: Line up 4 household objects from smallest to tallest.',
      ];
    }
    if (isSci) {
      return const <String>[
        '🌱 Leaf Detective: Spot a plant outside and talk about how roots drink water.',
        '☁️ Savanna Cloud Watch: Look at the sky and name which animal a cloud resembles.',
        '💧 Sink or Float Bowl: Guess together whether a spoon and a leaf float in water.',
      ];
    }
    return const <String>[
      '🗣️ Sound Safari: Spot 3 things in the room that start with the same letter sound.',
      '📖 Story Retell: Ask your child what happened first, next, and last in today’s story.',
      '🌍 3-Language High-Five: Say one animal name in English, Kiswahili, and French!',
    ];
  }
}

final watotoAiEngineProvider = Provider<WatotoAiEngine>((ref) {
  final store = ref.watch(offlineStoreProvider);
  return WatotoAiEngine(store: store);
});
