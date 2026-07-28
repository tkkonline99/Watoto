/// Pure daily-challenge selection (unit-tested; no Flutter imports).
///
/// Rotates the featured *subject* by calendar day, then pins the first
/// incomplete library item at the child's stage for that subject. Completing
/// that item grants [OfflineStore.dailyChallengeBonusXp] once per day.
library;

import '../../core/offline/offline_store.dart';
import '../curriculum/curriculum_data.dart';
import '../curriculum/curriculum_models.dart';
import '../curriculum/subject_catalog.dart';
import '../library/library_models.dart';
import '../library/library_repository.dart';
import '../profiles/child_profile.dart';

/// One concrete activity the child should play for today's challenge.
class DailyChallenge {
  const DailyChallenge({
    required this.item,
    required this.subject,
    required this.stage,
    required this.completed,
  });

  final LibraryItem item;
  final SubjectCategory subject;
  final CurriculumStage stage;
  final bool completed;

  String get itemId => item.id;
  String get title => item.title;
  String get emoji => subject.emoji;
}

/// Resolves the child's preferred play stage: last explicit pick, else age
/// derived from birth year.
CurriculumStage stageForChild(ChildProfile child, OfflineStore store) {
  final preferred = store.preferredStage(child.id);
  if (preferred != null) {
    for (final s in curriculumStages) {
      if (s.stage == preferred) return s;
    }
  }
  return stageForBirthYear(child.birthYear);
}

/// Candidates for today's challenge (today's subject × child's stage).
List<LibraryItem> dailyChallengeCandidates({
  required ChildProfile child,
  required OfflineStore store,
  required LibraryRepository library,
  DateTime? now,
}) {
  final date = now ?? DateTime.now();
  final stage = stageForChild(child, store);
  final subject = dailyChallengeSubjectFor(date);
  final topic = subject.topicNameFor(stage);
  if (topic == null) return const [];
  return library.forStageSubject(stage.stage, topic);
}

/// Picks (and pins) today's challenge for [child], or null when no content
/// exists for the featured subject at their stage.
///
/// Call [ensureDailyChallengePinned] from async UI/services so the target id
/// is written to the store; this pure resolver still works read-only.
DailyChallenge? resolveDailyChallenge({
  required ChildProfile child,
  required OfflineStore store,
  required LibraryRepository library,
  DateTime? now,
}) {
  final date = now ?? DateTime.now();
  final stage = stageForChild(child, store);
  final subject = dailyChallengeSubjectFor(date);
  final items = dailyChallengeCandidates(
    child: child,
    store: store,
    library: library,
    now: date,
  );
  if (items.isEmpty) return null;

  final byId = {for (final i in items) i.id: i};
  final pinned = store.dailyChallengeTargetId(child.id, now: date);
  final done = store.isDailyChallengeDone(child.id, now: date);

  LibraryItem item;
  if (pinned != null && byId.containsKey(pinned)) {
    item = byId[pinned]!;
  } else {
    // Prefer first incomplete so the challenge always has something to do.
    item = items.firstWhere(
      (i) => !store.hasCompletedLibraryItem(child.id, i.id, i.type.name),
      orElse: () => items.first,
    );
  }

  final completed = done ||
      store.hasCompletedLibraryItem(child.id, item.id, item.type.name);

  return DailyChallenge(
    item: item,
    subject: subject,
    stage: stage,
    completed: completed,
  );
}

/// Pins today's target if not already set. Safe to call on every home paint.
Future<DailyChallenge?> ensureDailyChallengePinned({
  required ChildProfile child,
  required OfflineStore store,
  required LibraryRepository library,
  DateTime? now,
}) async {
  final challenge = resolveDailyChallenge(
    child: child,
    store: store,
    library: library,
    now: now,
  );
  if (challenge == null) return null;
  await store.setDailyChallengeTarget(child.id, challenge.itemId, now: now);
  return challenge;
}

/// Whether finishing [itemId] should award today's daily-challenge bonus.
///
/// Safe to call *after* [itemId] has already been marked complete in the store:
/// when no target is pinned yet, the first candidate that is either incomplete
/// or equals [itemId] is treated as the challenge.
bool isTodaysChallengeItem({
  required String itemId,
  required ChildProfile child,
  required OfflineStore store,
  required LibraryRepository library,
  DateTime? now,
}) {
  final date = now ?? DateTime.now();
  if (store.isDailyChallengeDone(child.id, now: date)) return false;

  final pinned = store.dailyChallengeTargetId(child.id, now: date);
  if (pinned != null) return pinned == itemId;

  final items = dailyChallengeCandidates(
    child: child,
    store: store,
    library: library,
    now: date,
  );
  for (final i in items) {
    if (i.id == itemId) return true;
    final complete =
        store.hasCompletedLibraryItem(child.id, i.id, i.type.name);
    if (!complete) return false;
  }
  return false;
}
