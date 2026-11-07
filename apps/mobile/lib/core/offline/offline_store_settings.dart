/// Family settings: accessibility, narration, reminders, screen time,
/// chosen subjects, and the premium flag.
part of 'offline_store.dart';

extension OfflineStoreSettings on OfflineStore {
  // ------------------------------------------------------------- settings

  /// App-wide text-size multiplier layered on top of the OS text scale, so
  /// families can enlarge everything for young or low-vision readers. 1.0 =
  /// default; the accessibility control offers 1.0 / 1.3 / 1.6.
  double get textScale =>
      double.tryParse(_account.get('textScale') ?? '') ?? 1.0;

  Future<void> setTextScale(double scale) =>
      _account.put('textScale', scale.toString());

  /// Whether spoken narration (TTS) is on. Default on — the 0–5 band is
  /// audio-first, so pre-readers depend on it.
  bool get narrationEnabled => _account.get('narrationEnabled') != 'false';

  Future<void> setNarrationEnabled(bool enabled) =>
      _account.put('narrationEnabled', enabled ? 'true' : 'false');

  /// Reading-ease mode: larger letter-spacing + line height (no extra font asset).
  bool get dyslexiaFriendly => _account.get('dyslexiaFriendly') == 'true';

  Future<void> setDyslexiaFriendly(bool v) =>
      _account.put('dyslexiaFriendly', v ? 'true' : 'false');

  /// High-contrast theme tokens for low-vision readers.
  bool get highContrast => _account.get('highContrast') == 'true';

  Future<void> setHighContrast(bool v) =>
      _account.put('highContrast', v ? 'true' : 'false');

  /// Prefer reduced motion (mascot idle, celebrations).
  bool get reducedMotion => _account.get('reducedMotion') == 'true';

  Future<void> setReducedMotion(bool v) =>
      _account.put('reducedMotion', v ? 'true' : 'false');

  /// Cozy sunset / starry night bedtime mode ("Usiku Mwema").
  bool get bedtimeMode => _account.get('bedtimeMode') == 'true';

  Future<void> setBedtimeMode(bool v) =>
      _account.put('bedtimeMode', v ? 'true' : 'false');

  /// Parent opt-in for privacy-preserving product analytics (default off).
  bool get analyticsOptIn => _account.get('analyticsOptIn') == 'true';

  Future<void> setAnalyticsOptIn(bool v) =>
      _account.put('analyticsOptIn', v ? 'true' : 'false');

  ConsentRecord get consent {
    final raw = _account.get('consent');
    if (raw == null) return ConsentRecord.empty;
    return ConsentRecord.fromJson(
      (jsonDecode(raw) as Map).cast<String, dynamic>(),
    );
  }

  Future<void> saveConsent(ConsentRecord consent) =>
      _account.put('consent', jsonEncode(consent.toJson()));

  List<ChildProfile> get children {
    return _account.keys
        .where((k) => (k as String).startsWith('child:'))
        .map(
          (k) => ChildProfile.fromJson(
            (jsonDecode(_account.get(k)!) as Map).cast<String, dynamic>(),
          ),
        )
        .toList()
      ..sort(
        (a, b) => a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()),
      );
  }

  ChildProfile? childById(String id) {
    final raw = _account.get('child:$id');
    if (raw == null) return null;
    return ChildProfile.fromJson(
      (jsonDecode(raw) as Map).cast<String, dynamic>(),
    );
  }

  Future<ChildProfile> addChild({
    required String nickname,
    required String avatarKey,
    required int birthYear,
  }) async {
    final child = ChildProfile(
      id: OfflineStore._uuid.v4(),
      nickname: nickname,
      avatarKey: avatarKey,
      birthYear: birthYear,
      ageBand: ageBandForBirthYear(birthYear),
      // Null until first rename — parents may fix the initial nickname once.
    );
    await _account.put('child:${child.id}', jsonEncode(child.toJson()));
    return child;
  }

  Future<void> updateChild(ChildProfile child) =>
      _account.put('child:${child.id}', jsonEncode(child.toJson()));

  /// Renames a child profile if the 90-day cooldown has elapsed.
  /// Returns the updated profile. Throws [StoreError] when blocked.
  Future<ChildProfile> updateChildNickname({
    required String childId,
    required String nickname,
    DateTime? now,
  }) async {
    final child = childById(childId);
    if (child == null) {
      throw const StoreError(StoreErrorCode.childNotFound);
    }
    final name = nickname.trim();
    if (name.isEmpty) {
      throw const StoreError(StoreErrorCode.nicknameRequired);
    }
    if (name == child.nickname) return child;
    final when = now ?? DateTime.now().toUtc();
    if (!canChangeNickname(child.nicknameChangedAt, now: when)) {
      final days =
          nicknameCooldownDaysRemaining(child.nicknameChangedAt, now: when);
      throw StoreError(StoreErrorCode.nicknameCooldown, days: days);
    }
    final updated = child.copyWith(
      nickname: name,
      nicknameChangedAt: when,
    );
    await updateChild(updated);
    return updated;
  }

  /// Whether the parent may edit this child's nickname now.
  bool canEditChildNickname(String childId, {DateTime? now}) {
    final child = childById(childId);
    if (child == null) return false;
    return canChangeNickname(child.nicknameChangedAt, now: now);
  }

  /// Persists the full first-run result atomically enough for local use:
  /// consent, a parent gate (a PIN *or* a local account), first child, then
  /// marks onboarding complete + active child. Exactly one of [pin] /
  /// ([accountEmail] + [accountPassword]) is expected.
  Future<ChildProfile> completeOnboarding({
    required ConsentRecord consent,
    String? pin,
    String? accountEmail,
    String? accountPassword,
    required String nickname,
    required String avatarKey,
    required int birthYear,
  }) async {
    await saveConsent(consent);
    if (pin != null && pin.isNotEmpty) await setPin(pin);
    if (accountEmail != null && accountPassword != null) {
      await createAccount(accountEmail, accountPassword);
    }
    final child = await addChild(
      nickname: nickname,
      avatarKey: avatarKey,
      birthYear: birthYear,
    );
    await setActiveChild(child.id);
    await _account.put('onboardingComplete', 'true');
    return child;
  }

  // ------------------------------------------------------------ reminders

  /// Practice reminders. **Off unless a grown-up turns them on** — docs/12
  /// §12.6 forbids pushing anything to a child, so these are parent-facing
  /// and opt-in, never a default.
  bool get remindersEnabled => _account.get('remindersEnabled') == 'true';

  Future<void> setRemindersEnabled(bool on) =>
      _account.put('remindersEnabled', on ? 'true' : 'false');

  /// Local wall-clock hour for the daily reminder (default early evening).
  int get reminderHour =>
      int.tryParse(_account.get('reminderHour') ?? '') ?? 18;

  int get reminderMinute =>
      int.tryParse(_account.get('reminderMinute') ?? '') ?? 30;

  Future<void> setReminderTime(int hour, int minute) async {
    await _account.put('reminderHour', '${hour.clamp(0, 23)}');
    await _account.put('reminderMinute', '${minute.clamp(0, 59)}');
  }

  /// The last day [childId] finished anything, as 'yyyy-MM-dd', or null.
  String? lastActiveDayKey(String childId) =>
      _account.get('streakDate:$childId');

  // ------------------------------------------------------------- subjects

  /// Subjects this child has finished at least one activity in.
  ///
  /// Progress rows are keyed by item id only, so "have they been here before?"
  /// is not answerable from them — this keeps a small explicit set instead.
  Set<String> completedSubjects(String childId) {
    final raw = _account.get('subjects:$childId');
    if (raw == null || raw.isEmpty) return const {};
    return raw.split('\n').where((s) => s.isNotEmpty).toSet();
  }

  bool hasCompletedAnyInSubject(String childId, String subject) =>
      completedSubjects(childId).contains(subject);

  Future<void> markSubjectCompleted(String childId, String subject) async {
    if (subject.isEmpty) return;
    final set = {...completedSubjects(childId), subject};
    await _account.put('subjects:$childId', set.join('\n'));
  }

  // --------------------------------------------------------------- screen time

  /// Daily limit in minutes; 0 = unlimited (default).
  int screenTimeLimitMinutes() {
    final raw = _account.get('screenTimeLimit');
    return raw == null ? 0 : int.tryParse(raw) ?? 0;
  }

  Future<void> setScreenTimeLimitMinutes(int minutes) =>
      _account.put('screenTimeLimit', '${minutes < 0 ? 0 : minutes}');

  /// Seconds of learning time used today (all children, family device).
  int screenTimeUsedSeconds({DateTime? now}) {
    final day = OfflineStore._dayKey(now ?? DateTime.now());
    if (_account.get('screenTimeDay') != day) return 0;
    return _stats.get('screenTimeUsed', defaultValue: 0)!;
  }

  Future<void> addScreenTimeSeconds(int seconds, {DateTime? now}) async {
    if (seconds <= 0) return;
    final when = now ?? DateTime.now();
    final day = OfflineStore._dayKey(when);
    if (_account.get('screenTimeDay') != day) {
      await _account.put('screenTimeDay', day);
      await _stats.put('screenTimeUsed', 0);
    }
    await _stats.put(
      'screenTimeUsed',
      screenTimeUsedSeconds(now: when) + seconds,
    );
  }

  /// Soft-lock when a limit is set and today's usage is at/over it.
  bool isScreenTimeExceeded({DateTime? now}) {
    final limit = screenTimeLimitMinutes();
    if (limit <= 0) return false;
    return screenTimeUsedSeconds(now: now) >= limit * 60;
  }

  /// Parent grants a 10-minute grace extension (adds to limit for the day via
  /// reducing used time, or bumping a one-shot extension counter).
  Future<void> grantScreenTimeGrace({int minutes = 10}) async {
    final used = screenTimeUsedSeconds();
    final reduce = minutes * 60;
    await _stats.put(
      'screenTimeUsed',
      used > reduce ? used - reduce : 0,
    );
  }

  // --------------------------------------------------------------- premium

  /// Local entitlement mirror (sandbox + offline). Real source of truth is
  /// the Firebase account doc once payments are live.
  bool get hadPremiumBefore => _account.get('hadPremium') == 'true';

  /// Current entitlement from local storage.
  /// Import cycle avoided: returns a simple record consumed by entitlements.dart.
  ({String plan, DateTime? expiry, bool isPremium}) get entitlementRaw {
    final plan = _account.get('plan') ?? 'free';
    final expRaw = _account.get('entitlementExpiry');
    DateTime? exp;
    if (expRaw != null) exp = DateTime.tryParse(expRaw);
    final premium = plan == 'premium' &&
        (exp == null || exp.isAfter(DateTime.now()));
    return (plan: premium ? 'premium' : 'free', expiry: exp, isPremium: premium);
  }

  Future<void> setLocalPremium(
    bool premium, {
    DateTime? expiry,
    String source = 'local',
  }) async {
    if (premium) {
      await _account.put('plan', 'premium');
      await _account.put(
        'entitlementExpiry',
        (expiry ?? DateTime.now().add(const Duration(days: 30)))
            .toIso8601String(),
      );
      await _account.put('hadPremium', 'true');
      await _account.put('premiumSource', source);
    } else {
      await _account.put('plan', 'free');
      await _account.delete('entitlementExpiry');
    }
  }

  // --------------------------------------------------------------- voice packs

  /// Whether the downloadable neural voiceover pack for [langCode] (`en`, `sw`,
  /// `fr`) has been installed on this device.
  bool isVoicePackInstalled(String langCode) =>
      _account.get('voicePackInstalled:$langCode') == 'true';

  /// Number of MP3 clips extracted for [langCode], or 0 when not installed.
  int voicePackClipCount(String langCode) =>
      int.tryParse(_account.get('voicePackCount:$langCode') ?? '') ?? 0;

  /// Records installation state and clip count for [langCode]'s neural voice pack.
  Future<void> setVoicePackInstalled(
    String langCode, {
    required bool installed,
    int clipCount = 0,
  }) async {
    if (installed) {
      await _account.put('voicePackInstalled:$langCode', 'true');
      await _account.put('voicePackCount:$langCode', '$clipCount');
    } else {
      await _account.delete('voicePackInstalled:$langCode');
      await _account.delete('voicePackCount:$langCode');
    }
  }
}
