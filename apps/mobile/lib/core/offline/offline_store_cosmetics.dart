/// Everything a child can earn or wear. None of it gates a lesson —
/// coins buy looks only (docs/12).
part of 'offline_store.dart';

extension OfflineStoreCosmetics on OfflineStore {
  // --------------------------------------------------------------- coins

  int coinsFor(String childId) =>
      _stats.get('coins:$childId', defaultValue: 0)!;

  int coinsEarnedToday(String childId, {DateTime? now}) {
    final day = OfflineStore._dayKey(now ?? DateTime.now());
    if (_account.get('coinsDay:$childId') != day) return 0;
    return _stats.get('coinsToday:$childId', defaultValue: 0)!;
  }

  /// Grants [amount] coins subject to the daily cap. Returns coins actually
  /// granted.
  Future<int> grantCoins(
    String childId,
    int amount, {
    DateTime? now,
  }) async {
    if (amount <= 0) return 0;
    final when = now ?? DateTime.now();
    final day = OfflineStore._dayKey(when);
    if (_account.get('coinsDay:$childId') != day) {
      await _account.put('coinsDay:$childId', day);
      await _stats.put('coinsToday:$childId', 0);
    }
    final earned = coinsEarnedToday(childId, now: when);
    final room = 30 - earned; // matches economy.dailyCoinCap
    if (room <= 0) return 0;
    final grant = amount > room ? room : amount;
    await _stats.put('coins:$childId', coinsFor(childId) + grant);
    await _stats.put('coinsToday:$childId', earned + grant);
    return grant;
  }

  Future<bool> spendCoins(String childId, int amount) async {
    if (amount <= 0) return true;
    final bal = coinsFor(childId);
    if (bal < amount) return false;
    await _stats.put('coins:$childId', bal - amount);
    return true;
  }

  // --------------------------------------------------------------- avatars

  Set<String> unlockedAvatars(String childId) {
    final raw = _account.get('avatars:$childId');
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  Future<void> unlockAvatar(String childId, String key) async {
    final set = unlockedAvatars(childId)..add(key);
    await _account.put('avatars:$childId', set.join(','));
  }

  bool isAvatarUnlocked(String childId, String key) =>
      unlockedAvatars(childId).contains(key);

  // ------------------------------------------------------------- home themes

  /// Home backdrop themes bought with coins. Same shape as avatars: cosmetic
  /// only — a theme never gates an activity (docs/12: coins buy looks, never
  /// lessons).
  Set<String> unlockedHomeThemes(String childId) {
    final raw = _account.get('themes:$childId');
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  Future<void> unlockHomeTheme(String childId, String key) async {
    final set = unlockedHomeThemes(childId)..add(key);
    await _account.put('themes:$childId', set.join(','));
  }

  bool isHomeThemeUnlocked(String childId, String key) =>
      unlockedHomeThemes(childId).contains(key);

  /// The theme currently worn, or null for the default savanna.
  String? homeTheme(String childId) {
    final key = _account.get('theme:$childId');
    return (key == null || key.isEmpty) ? null : key;
  }

  /// Wears [key]. Passing null (or a locked key) returns to the default, so a
  /// content update that drops a theme cannot leave a child on a blank home.
  Future<void> setHomeTheme(String childId, String? key) async {
    if (key == null || key.isEmpty || !isHomeThemeUnlocked(childId, key)) {
      await _account.delete('theme:$childId');
      return;
    }
    await _account.put('theme:$childId', key);
  }

  // ------------------------------------------------- first-of-day high five

  /// Local date stamp of the last first-of-day celebration, or null.
  ///
  /// Stored as a local `YYYY-MM-DD` string rather than an epoch: the question
  /// asked is "was that today, where the child is", and a timezone-naive date
  /// answers it without the midnight-boundary bugs an epoch invites.
  String? firstDayHighFiveOn(String childId) =>
      _account.get('highfive:$childId');

  bool hasFirstDayHighFiveToday(String childId, {DateTime? now}) =>
      firstDayHighFiveOn(childId) == _localDay(now ?? DateTime.now());

  Future<void> markFirstDayHighFive(String childId, {DateTime? now}) =>
      _account.put('highfive:$childId', _localDay(now ?? DateTime.now()));

  // ------------------------------------------------------------ stretch break

  /// When the stretch prompt was last shown, in epoch seconds, or null.
  int? lastStretchAtEpochS(String childId) {
    final raw = _account.get('stretch:$childId');
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> markStretchShown(String childId, {DateTime? now}) =>
      _account.put(
        'stretch:$childId',
        ((now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000).toString(),
      );

  static String _localDay(DateTime at) =>
      '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------- savanna decorations

  /// Decorations this child has bought with coins. Earned decorations are
  /// derived from progress and are not stored.
  Set<String> unlockedDecorations(String childId) {
    final raw = _account.get('decor:$childId');
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  Future<void> unlockDecoration(String childId, String key) async {
    final set = unlockedDecorations(childId)..add(key);
    await _account.put('decor:$childId', set.join(','));
  }

  bool isDecorationUnlocked(String childId, String key) =>
      unlockedDecorations(childId).contains(key);

  // ---------------------------------------------------------------- cheers

  /// A cheer a grown-up left for this child, as 'kind|iso8601', or null.
  /// Read by the child's home screen and cleared once seen.
  String? pendingCheer(String childId) => _account.get('cheer:$childId');

  Future<void> sendCheer(String childId, String encoded) =>
      _account.put('cheer:$childId', encoded);

  Future<void> clearCheer(String childId) =>
      _account.delete('cheer:$childId');

  // ---------------------------------------------------------------- mascot

  /// The name the child gave their companion, or null while it is still just
  /// "the lion". A named companion is a relationship; an unnamed one is a
  /// decoration.
  String? mascotName(String childId) {
    final raw = _account.get('mascotName:$childId');
    return (raw == null || raw.trim().isEmpty) ? null : raw;
  }

  Future<void> setMascotName(String childId, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      await _account.delete('mascotName:$childId');
      return;
    }
    // Same ceiling as a child nickname — long enough to be theirs, short
    // enough to fit a speech bubble.
    await _account.put(
      'mascotName:$childId',
      clean.length > 16 ? clean.substring(0, 16) : clean,
    );
  }

  // --------------------------------------------------------------- stars

  int totalStars(String childId) =>
      _stats.get('stars:$childId', defaultValue: 0)!;

  /// Best star rating recorded for a quiz (0–3).
  int starsForQuiz(String childId, String quizId) {
    final m = lastQuizAttempt(childId, quizId);
    if (m == null) return 0;
    return (m['stars'] as int?) ?? 0;
  }
}
