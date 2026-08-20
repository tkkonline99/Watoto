import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'core/offline/offline_providers.dart';
import 'features/curriculum/subject_catalog.dart';
import 'features/gamification/daily_challenge.dart';
import 'features/library/library_models.dart';
import 'features/library/library_repository.dart';
import 'features/parent/family_layer.dart';

/// Demo entrypoint (NOT shipped): seeds an onboarded family so the app boots
/// past onboarding for screenshots and manual exploration.
///
/// Uses the same [bootstrapWatoto] path as production so desktop/web demos
/// get auth, sync lifecycle, and Hive migration — not a stale mini-main.
///
///   flutter run -t lib/main_demo.dart -d windows
///   flutter run -t lib/main_demo.dart -d chrome --dart-define=START=/
///
/// The seeded family has a PIN, and the login gate asks for it on every
/// launch, so add `--dart-define=DEMO_SKIP_LOGIN=true` (see
/// [kDemoSkipLoginGate]) for a demo or screenshot run that nobody is sitting
/// at to type it.
Future<void> main() async {
  final container = await bootstrapWatoto(seedDemoFamily: true);
  await _seedShowcase(container);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const WatotoApp(),
    ),
  );
}

/// Gives the demo family enough history that the progress-driven surfaces
/// actually have something to show.
///
/// The plain demo seed grants one synthetic lesson, which leaves every
/// progress surface in its empty state: 0% subject rings, an empty savanna, a
/// 1/3 quest. This completes *real* library items instead, so the rings, the
/// earned decorations and the companion all reflect genuine progress.
///
/// Demo-only, and idempotent — a second launch is a no-op.
Future<void> _seedShowcase(ProviderContainer container) async {
  final store = container.read(offlineStoreProvider);
  final childId = store.activeChildId;
  if (childId == null) return;
  // Marker so re-running the demo does not seed on top of itself.
  if (store.completedSubjects(childId).isNotEmpty) return;

  final child = store.childById(childId);
  if (child == null) return;

  final library = await LibraryRepository.load();
  final stage = stageForChild(child, store);

  // Finish the first couple of activities in three subjects: enough to fill
  // some rings partway, leave the others empty for contrast, and clear the
  // progress gates on the savanna decorations.
  var seeded = 0;
  for (final subject in subjectCatalog.take(3)) {
    final topic = subject.topicNameFor(stage);
    if (topic == null) continue;
    final items = library.forStageSubject(stage.stage, topic);
    for (final item in items.take(2)) {
      switch (item.type) {
        case LibraryType.story:
          await store.recordStoryRead(
            childId: childId,
            storyId: item.id,
            xpEarned: item.xp,
          );
        case LibraryType.quiz:
          await store.recordQuizAttempt(
            childId: childId,
            quizId: item.id,
            scorePct: 100,
            passed: true,
            answers: const [],
            durationS: 90,
            xpEarned: item.xp,
            stars: 3,
          );
        case LibraryType.lesson:
          await store.recordLessonCompleted(
            childId: childId,
            lessonId: item.id,
            scorePct: 100,
            timeSpentS: 90,
            xpEarned: item.xp,
          );
      }
      await store.markSubjectCompleted(childId, item.subject);
      seeded++;
    }
  }
  if (seeded == 0) return;

  // Two decorations already bought, so the savanna shows both halves of the
  // economy: earned and purchased.
  await store.unlockDecoration(childId, 'hut');
  await store.unlockDecoration(childId, 'palm');

  // A cheer waiting from a grown-up.
  await store.sendCheer(
    childId,
    encodeCheer(CheerKind.proud, DateTime.now()),
  );

  // XP and streak are written straight to the Hive boxes the store already
  // opened. There is no production setter for either — XP is earned, and a
  // streak ticks once per calendar day — and a demo cannot wait five days.
  // Demo-only reach-through; never do this from app code.
  final stats = Hive.box<int>('stats');
  await stats.put('xp:$childId', 720); // ~level 4: unlocks acacia + elephant
  await stats.put('streak:$childId', 5); // proud companion, lit streak pill
  // Coins are written as a *balance* rather than granted, on purpose: granting
  // would consume today's 30-coin earn cap, and the next activity would then
  // pay out nothing and the celebration would show no coins at all.
  await stats.put('coins:$childId', 42);
}
