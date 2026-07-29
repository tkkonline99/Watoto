/// Seeds a demo child + light progress for store screenshots and QA demos.
///
/// Pure orchestration over [OfflineStore] — no Flutter UI imports.
library;

import '../../core/offline/offline_store.dart';
import '../profiles/child_profile.dart';

/// Fixed nickname used so screenshot scripts stay predictable.
const String demoSeedNickname = 'Amani';

/// Result of a seed run.
class DemoSeedResult {
  const DemoSeedResult({
    required this.child,
    required this.createdNew,
    required this.lessonsSeeded,
  });

  final ChildProfile child;
  final bool createdNew;
  final int lessonsSeeded;
}

/// Ensure a demo profile exists with a few completed activities and coins/XP
/// so Home / celebration / shop look lively in screenshots.
///
/// Idempotent for the same day: reuses an existing [demoSeedNickname] child
/// when present; still tops up a few lesson completions if XP is very low.
Future<DemoSeedResult> seedDemoProfile(OfflineStore store) async {
  final existing = store.children.where(
    (c) => c.nickname.toLowerCase() == demoSeedNickname.toLowerCase(),
  );
  ChildProfile child;
  var createdNew = false;
  if (existing.isNotEmpty) {
    child = existing.first;
  } else {
    child = await store.addChild(
      nickname: demoSeedNickname,
      avatarKey: 'lion',
      birthYear: DateTime.now().year - 5,
    );
    createdNew = true;
  }

  await store.setActiveChild(child.id);

  var lessonsSeeded = 0;
  final xp = store.xpFor(child.id);
  if (xp < 40) {
    // A few completed free-tier items for badges / level bar / weekly card.
    const ids = <String>[
      's01.cause.lesson.01',
      's01.sensory.lesson.01',
      's02.animals.lesson.01',
      's03.counting.lesson.01',
    ];
    for (final id in ids) {
      if (store.progressFor(child.id, id) != null) continue;
      await store.recordLessonCompleted(
        childId: child.id,
        lessonId: id,
        scorePct: 100,
        timeSpentS: 90 + lessonsSeeded * 20,
        xpEarned: 10,
      );
      await store.grantCoins(child.id, 2);
      lessonsSeeded++;
    }
  }

  // Unlock a shop theme sample for screenshot variety (no cost in seed).
  if (!store.isHomeThemeUnlocked(child.id, 'ocean')) {
    await store.unlockHomeTheme(child.id, 'ocean');
  }
  await store.setHomeTheme(child.id, 'ocean');

  // Mark guided tour done so home shows Play now cleanly.
  await store.markGuidedTourDone(child.id);

  return DemoSeedResult(
    child: child,
    createdNew: createdNew,
    lessonsSeeded: lessonsSeeded,
  );
}
