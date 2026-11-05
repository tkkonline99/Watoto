/// The savanna as a progress surface rather than wallpaper.
///
/// Two things put something into a child's scene:
///
/// * **Earned** — unlocked by real progress (levels, subjects explored). Free,
///   and the reason the world visibly grows as they learn.
/// * **Bought** — a coin sink deep enough to matter. The avatar shop alone was
///   six emoji at 15–35 coins against a 30/day cap, so a motivated child
///   exhausted it in about three days and coins stopped meaning anything.
///
/// Pure data + rules: no Flutter, no store, so it is cheap to unit-test.
library;

enum DecorSource { earned, bought }

/// One thing that can appear in the scene.
class SavannaDecoration {
  const SavannaDecoration({
    required this.key,
    required this.emoji,
    required this.source,
    required this.x,
    required this.y,
    this.cost = 0,
    this.scale = 1.0,
    this.requiredLevel = 0,
    this.requiredSubjects = 0,
  });

  final String key;
  final String emoji;
  final DecorSource source;

  /// Placement as a fraction of the scene: [x] across, [y] down the ground
  /// band. Fixed per decoration so a child's savanna looks the same each time.
  final double x;
  final double y;

  /// Coin price (0 for earned decorations).
  final int cost;

  /// Relative size — distant things are drawn smaller.
  final double scale;

  /// Progress gates for earned decorations.
  final int requiredLevel;
  final int requiredSubjects;

  bool get isBuyable => source == DecorSource.bought;
}

/// Earned by playing — this is what makes the world grow on its own.
const List<SavannaDecoration> earnedDecorations = [
  SavannaDecoration(
    key: 'zebra',
    emoji: '🦓',
    source: DecorSource.earned,
    x: 0.68,
    y: 0.34,
    scale: 0.9,
    requiredSubjects: 1,
  ),
  SavannaDecoration(
    key: 'acacia',
    emoji: '🌿',
    source: DecorSource.earned,
    x: 0.30,
    y: 0.20,
    scale: 0.8,
    requiredLevel: 2,
  ),
  SavannaDecoration(
    key: 'elephant',
    emoji: '🐘',
    source: DecorSource.earned,
    x: 0.46,
    y: 0.52,
    requiredLevel: 3,
  ),
  SavannaDecoration(
    key: 'giraffe',
    emoji: '🦒',
    source: DecorSource.earned,
    x: 0.82,
    y: 0.12,
    scale: 1.1,
    requiredSubjects: 3,
  ),
  SavannaDecoration(
    key: 'lion',
    emoji: '🦁',
    source: DecorSource.earned,
    x: 0.16,
    y: 0.56,
    requiredLevel: 5,
  ),
  SavannaDecoration(
    key: 'hippo',
    emoji: '🦛',
    source: DecorSource.earned,
    x: 0.58,
    y: 0.72,
    requiredSubjects: 5,
  ),
];

/// Bought with coins. Prices climb so the shop stays worth returning to:
/// the full set runs to several weeks of play against the 30/day earn cap,
/// instead of the three days the avatar shop lasted.
const List<SavannaDecoration> shopDecorations = [
  SavannaDecoration(
    key: 'flowers',
    emoji: '🌼',
    source: DecorSource.bought,
    cost: 10,
    x: 0.10,
    y: 0.30,
    scale: 0.7,
  ),
  SavannaDecoration(
    key: 'bush',
    emoji: '🌳',
    source: DecorSource.bought,
    cost: 15,
    x: 0.90,
    y: 0.44,
    scale: 0.8,
  ),
  SavannaDecoration(
    key: 'rock',
    emoji: '🪨',
    source: DecorSource.bought,
    cost: 20,
    x: 0.36,
    y: 0.66,
    scale: 0.75,
  ),
  SavannaDecoration(
    key: 'palm',
    emoji: '🌴',
    source: DecorSource.bought,
    cost: 25,
    x: 0.74,
    y: 0.60,
  ),
  SavannaDecoration(
    key: 'hut',
    emoji: '🛖',
    source: DecorSource.bought,
    cost: 30,
    x: 0.24,
    y: 0.42,
  ),
  SavannaDecoration(
    key: 'drum',
    emoji: '🥁',
    source: DecorSource.bought,
    cost: 35,
    x: 0.52,
    y: 0.28,
    scale: 0.7,
  ),
  SavannaDecoration(
    key: 'parrot',
    emoji: '🦜',
    source: DecorSource.bought,
    cost: 40,
    x: 0.62,
    y: 0.08,
    scale: 0.7,
  ),
  SavannaDecoration(
    key: 'monkey',
    emoji: '🐒',
    source: DecorSource.bought,
    cost: 50,
    x: 0.40,
    y: 0.06,
    scale: 0.8,
  ),
  SavannaDecoration(
    key: 'rhino',
    emoji: '🦏',
    source: DecorSource.bought,
    cost: 60,
    x: 0.06,
    y: 0.70,
  ),
  SavannaDecoration(
    key: 'baobab',
    emoji: '🌲',
    source: DecorSource.bought,
    cost: 75,
    x: 0.88,
    y: 0.74,
    scale: 1.2,
  ),
  SavannaDecoration(
    key: 'butterflies',
    emoji: '🦋',
    source: DecorSource.bought,
    cost: 90,
    x: 0.20,
    y: 0.08,
    scale: 0.8,
  ),
  SavannaDecoration(
    key: 'rainbow',
    emoji: '🌈',
    source: DecorSource.bought,
    cost: 120,
    x: 0.50,
    y: 0.00,
    scale: 1.4,
  ),
];

/// Every decoration, earned and bought.
List<SavannaDecoration> get allDecorations => [
      ...earnedDecorations,
      ...shopDecorations,
    ];

SavannaDecoration? decorationByKey(String key) {
  for (final d in allDecorations) {
    if (d.key == key) return d;
  }
  return null;
}

/// Total coins needed to buy out the shop — the depth of the sink.
int get shopTotalCost =>
    shopDecorations.fold(0, (sum, d) => sum + d.cost);

/// Whether [decoration] has been earned at this level / breadth of study.
bool isEarned(
  SavannaDecoration decoration, {
  required int level,
  required int subjectsExplored,
}) =>
    decoration.source == DecorSource.earned &&
    level >= decoration.requiredLevel &&
    subjectsExplored >= decoration.requiredSubjects;

/// Everything visible in a child's savanna right now.
List<SavannaDecoration> visibleDecorations({
  required Set<String> purchased,
  required int level,
  required int subjectsExplored,
}) =>
    [
      for (final d in earnedDecorations)
        if (isEarned(d, level: level, subjectsExplored: subjectsExplored)) d,
      for (final d in shopDecorations)
        if (purchased.contains(d.key)) d,
    ];

/// The next thing progress alone will add, for a "keep going" hint. Null once
/// every earned decoration is unlocked.
SavannaDecoration? nextEarnedDecoration({
  required int level,
  required int subjectsExplored,
}) {
  for (final d in earnedDecorations) {
    if (!isEarned(d, level: level, subjectsExplored: subjectsExplored)) {
      return d;
    }
  }
  return null;
}

/// Trilingual Savanna greeting & fun fact when a child taps an unlocked animal
/// or landmark sticker in their Savanna world.
String savannaStickerGreeting(String key, String lang) {
  final code = lang.toLowerCase();
  const lines = <String, ({String en, String sw, String fr})>{
    'zebra': (
      en: 'Jambo! Every zebra has one-of-a-kind stripes!',
      sw: 'Jambo! Kila punda milia ana mistari ya kipekee!',
      fr: 'Jambo ! Chaque zèbre a des rayures uniques !',
    ),
    'acacia': (
      en: 'Shady acacia trees feed giraffes and shelter birds!',
      sw: 'Miti ya mkunga huwapa twiga chakula na ndege kivuli!',
      fr: 'Les acacias nourrissent les girafes et abritent les oiseaux !',
    ),
    'elephant': (
      en: 'Hooray! Elephants use their trunks to wave hello!',
      sw: 'Hongera! Tembo hutumia mkonga wake kusalimia!',
      fr: 'Bravo ! Les éléphants saluent avec leur trompe !',
    ),
    'giraffe': (
      en: 'Twiga the giraffe can see all across the savanna!',
      sw: 'Twiga anaweza kuona savana nzima kutoka juu!',
      fr: 'La girafe voit toute la savane depuis là-haut !',
    ),
    'lion': (
      en: 'Roar! Simba the lion loves learning with you!',
      sw: 'Ngurumo! Simba anapenda kujifunza na wewe!',
      fr: 'Rugissement ! Simba adore apprendre avec toi !',
    ),
    'hippo': (
      en: 'Splash! Hippos stay cool in the river all day!',
      sw: 'Chubwi! Kiboko hupenda kukaa mtoni mchana kutwa!',
      fr: 'Plouf ! Les hippopotames restent au frais dans la rivière !',
    ),
    'flowers': (
      en: 'Bright savanna flowers bloom after the rain!',
      sw: 'Maua mazuri ya savanauchanua baada ya mvua!',
      fr: 'Les fleurs de la savane éclosent après la pluie !',
    ),
    'bush': (
      en: 'Green savanna bushes hide little beetles and birds!',
      sw: 'Vichaka vya kijani huficha wadudu na ndege wadogo!',
      fr: 'Les buissons verts cachent de petits oiseaux !',
    ),
    'rock': (
      en: 'Warm sun rocks where lizards love to rest!',
      sw: 'Mawe yenye joto ambapo mijusi hupenda kupumzika!',
      fr: 'Des rochers chauds où les lézards se reposent !',
    ),
    'palm': (
      en: 'Tall palm trees sway in the warm breeze!',
      sw: 'Mitende mirefu inayumba kwenye upepo mwanana!',
      fr: 'Les grands palmiers dansent dans la brise !',
    ),
    'hut': (
      en: 'Karibu! A cozy village home for story time!',
      sw: 'Karibu! Nyumba nzuri ya kijijini kwa wakati wa hadithi!',
      fr: 'Karibu ! Une maison accueillante pour les histoires !',
    ),
    'drum': (
      en: 'Boom-tap! The savanna drum calls everyone to dance!',
      sw: 'Bumu-tap! Ngoma ya savana inaita kila mtu kucheza!',
      fr: 'Boum-tap ! Le tambour invite tout le monde à danser !',
    ),
    'parrot': (
      en: 'Squawk! The colorful parrot repeats your new words!',
      sw: 'Kasuku mwenye rangi nyingi anarudia maneno yako mapya!',
      fr: 'Le perroquet coloré répète tes nouveaux mots !',
    ),
    'monkey': (
      en: 'Ooh-ooh! Tumbili the monkey swings from branch to branch!',
      sw: 'Tumbili anaruka kutoka tawi hadi tawi kwa furaha!',
      fr: 'Le petit singe saute de branche en branche !',
    ),
    'rhino': (
      en: 'Steady and strong! Kifaru the rhino charges ahead!',
      sw: 'Imara na hodari! Kifaru anasonga mbele!',
      fr: 'Fort et courageux ! Le rhinocéros avance !',
    ),
    'baobab': (
      en: 'The giant baobab is the tree of life on the savanna!',
      sw: 'Mbuyu mkubwa ni mti wa uzima katika savana!',
      fr: 'Le grand baobab est l’arbre de vie de la savane !',
    ),
    'butterflies': (
      en: 'Flutter, flutter! Butterflies dance in the sunshine!',
      sw: 'Vipepeo wanacheza kwenye mwanga wa jua!',
      fr: 'Les papillons dansent dans la lumière du soleil !',
    ),
    'rainbow': (
      en: 'Seven bright colors shining over the savanna!',
      sw: 'Rangi saba angavu zinang’aa juu ya savana!',
      fr: 'Sept belles couleurs brillent sur la savane !',
    ),
  };

  final entry = lines[key];
  if (entry == null) {
    return switch (code) {
      'sw' => 'Hongera! Savana yako inakua!',
      'fr' => 'Bravo ! Ta savane grandit !',
      _ => 'Hooray! Your savanna is growing!',
    };
  }
  return switch (code) {
    'sw' => entry.sw,
    'fr' => entry.fr,
    _ => entry.en,
  };
}

/// Playful, encouraging lines Kibo the lion cub speaks when tickled/tapped on
/// the Home screen. Adapts to morning/evening hours when [hour] is supplied.
String mascotTickleSpeech(int tapIndex, String lang, {int? hour}) {
  final code = lang.toLowerCase();
  final en = <String>[
    if (hour != null && hour < 12)
      'Good morning, rafiki! Ready for a sunny savanna adventure?'
    else if (hour != null && hour >= 18)
      'Cozy evening, friend! Let us read a story under the stars!'
    else
      'Hehehe, that tickles! Twende, let us learn together!',
    'Roar! You have a superpower brain today!',
    'High paw! Every star you earn grows our savanna!',
    'Asante rafiki! Tap a subject tile and let us play!',
  ];
  final sw = <String>[
    if (hour != null && hour < 12)
      'Habari za asubuhi rafiki! Twende tukajifunze!'
    else if (hour != null && hour >= 18)
      'Jioni njema rafiki! Tusome hadithi chini ya nyota!'
    else
      'Hehehe, unanichekesha! Twende tujifunze pamoja!',
    'Ngurumo! Akili yako inang’aa sana leo!',
    'Gonga tano! Kila nyota inakuza savana yetu!',
    'Asante rafiki! Gusa somo tuanze kucheza!',
  ];
  final fr = <String>[
    if (hour != null && hour < 12)
      'Bonjour mon ami ! Prêt pour une aventure dans la savane ?'
    else if (hour != null && hour >= 18)
      'Bonsoir mon ami ! Lisons une histoire sous les étoiles !'
    else
      'Hahaha, ça chatouille ! Apprenons ensemble !',
    'Rugissement ! Tu es super curieux aujourd’hui !',
    'Tape-m’en cinq ! Chaque étoile fait grandir notre savane !',
    'Merci mon ami ! Touche une matière pour jouer !',
  ];

  final list = switch (code) {
    'sw' => sw,
    'fr' => fr,
    _ => en,
  };
  return list[tapIndex.abs() % list.length];
}
