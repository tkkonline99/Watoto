/// Ports for offline-first persistence. Hive implements these today;
/// Firestore can implement the same contracts later without UI changes.
library;

import '../models/child_profile.dart';
import '../models/consent.dart';

abstract interface class AccountRepository {
  bool get onboardingComplete;
  bool get isLoggedIn;
  bool get hasPin;
  ConsentRecord get consent;
  List<ChildProfile> get children;
  ChildProfile? childById(String id);
  String? get activeChildId;

  Future<void> setActiveChild(String childId);
  Future<void> saveConsent(ConsentRecord consent);
}

abstract interface class ProgressRepository {
  bool isLessonCompleted(String childId, String lessonId);
  bool isQuizPassed(String childId, String quizId);
  bool isStoryRead(String childId, String storyId);
  int completedLessonCount(String childId);
  int completedStoryCount(String childId);
}

abstract interface class EconomyRepository {
  int xpFor(String childId);
  int streakFor(String childId);
  int coinsFor(String childId);
  int totalStars(String childId);
}

abstract interface class SettingsRepository {
  String? get localeCode;
  Future<void> setLocaleCode(String code);
  double get textScale;
  bool get highContrast;
  bool get reducedMotion;
  bool get dyslexiaFriendly;
  bool get analyticsOptIn;
}

abstract interface class SyncQueueRepository {
  int get pendingOpCount;
  String? get lastSyncError;
  DateTime? get lastSyncAt;
}
