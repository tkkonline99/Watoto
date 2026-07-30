/// Quiz star ratings — single source of truth for all players.
///
/// Kinder thresholds for ages 0–10 (product decision vs. harsh 70/90):
/// 100% → 3★, ≥67% → 2★, ≥40% → 1★, else 0.
/// See docs/12-gamification.md (MVP note).
library;

/// Stars from a quiz score percentage.
int starsFromScorePct(int scorePct) {
  if (scorePct >= 100) return 3;
  if (scorePct >= 67) return 2;
  if (scorePct >= 40) return 1;
  return 0;
}

/// First-star threshold (percent).
const int starThreshold1 = 40;

/// Second-star threshold (percent).
const int starThreshold2 = 67;

/// Third-star threshold (percent).
const int starThreshold3 = 100;
