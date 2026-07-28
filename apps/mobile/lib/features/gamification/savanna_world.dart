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
