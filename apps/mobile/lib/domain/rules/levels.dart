/// Level curve per docs/12-gamification.md:
/// cumulative XP to *enter* level n is `floor(100 × n^1.4)` for n ≥ 2
/// (L2≈264, L5≈951, L10≈2512). Level 1 starts at 0 XP.
library;

import 'dart:math' as math;

/// Cumulative XP required to enter [level] (level 1 → 0).
int cumulativeXpToEnterLevel(int level) {
  if (level <= 1) return 0;
  return (100 * math.pow(level, 1.4)).floor();
}

/// Level for a total XP balance (minimum 1).
int levelForXp(int xp) {
  final safe = xp < 0 ? 0 : xp;
  var level = 1;
  // Cap search so pathological XP cannot hang.
  while (level < 500) {
    final next = cumulativeXpToEnterLevel(level + 1);
    if (safe < next) return level;
    level++;
  }
  return level;
}

/// XP already earned inside the current level (0 .. span-1).
int xpIntoLevel(int xp) {
  final safe = xp < 0 ? 0 : xp;
  final level = levelForXp(safe);
  return safe - cumulativeXpToEnterLevel(level);
}

/// Width of the current level band (XP needed to go from L → L+1).
int xpSpanForLevel(int level) {
  final start = cumulativeXpToEnterLevel(level);
  final end = cumulativeXpToEnterLevel(level + 1);
  final span = end - start;
  return span <= 0 ? 1 : span;
}

/// XP still needed to reach the next level.
int xpToNextLevel(int xp) {
  final safe = xp < 0 ? 0 : xp;
  final level = levelForXp(safe);
  return cumulativeXpToEnterLevel(level + 1) - safe;
}

/// 0..1 progress toward the next level.
double levelProgress(int xp) {
  final level = levelForXp(xp);
  return xpIntoLevel(xp) / xpSpanForLevel(level);
}

/// @deprecated Prefer [xpSpanForLevel]. Kept for UI that shows a "total" slot.
@Deprecated('Use xpSpanForLevel(levelForXp(xp))')
const int xpPerLevel = 100;
