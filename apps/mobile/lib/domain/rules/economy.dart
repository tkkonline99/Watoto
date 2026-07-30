/// Coin economy + avatar shop (design doc §12.1 — cosmetic only).
library;

/// Daily coin earn cap — prevents grind loops.
const int dailyCoinCap = 30;

/// Coins granted per activity type (first completion / pass).
const int coinsLesson = 1;
const int coinsQuizPass = 2;
const int coinsStory = 1;
const int coinsDailyChallenge = 5;

/// An unlockable avatar outfit (emoji key + cost).
class ShopAvatar {
  const ShopAvatar(this.key, this.emoji, this.cost);
  final String key;
  final String emoji;
  final int cost;
}

/// Always-unlocked base set (matches historical free choices).
const Map<String, String> baseAvatarChoices = {
  'lion': '🦁',
  'elephant': '🐘',
  'giraffe': '🦒',
  'zebra': '🦓',
  'hippo': '🦛',
  'monkey': '🐵',
};

/// Coin shop — locked until purchased with coins.
const List<ShopAvatar> shopAvatars = [
  ShopAvatar('parrot', '🦜', 15),
  ShopAvatar('turtle', '🐢', 15),
  ShopAvatar('fox', '🦊', 20),
  ShopAvatar('panda', '🐼', 25),
  ShopAvatar('tiger', '🐯', 30),
  ShopAvatar('owl', '🦉', 35),
];

/// All known emoji keys (base + shop).
Map<String, String> allAvatarEmojis() => {
      ...baseAvatarChoices,
      for (final s in shopAvatars) s.key: s.emoji,
    };

String avatarEmojiFor(String key) =>
    allAvatarEmojis()[key] ?? baseAvatarChoices['lion']!;

/// How many coins to grant for this reward, after applying the daily cap.
int cappedCoinGrant({
  required int requested,
  required int alreadyEarnedToday,
}) {
  if (requested <= 0) return 0;
  final room = dailyCoinCap - alreadyEarnedToday;
  if (room <= 0) return 0;
  return requested > room ? room : requested;
}
