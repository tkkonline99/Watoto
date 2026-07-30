import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/features/gamification/today_quest.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';

void main() {
  late OfflineStore store;

  setUp(() async {
    Hive.init(null);
    store = await OfflineStore.open(inMemory: true);
  });

  tearDown(() async {
    await store.close();
  });

  test('today quest counts same-day completions', () async {
    final child = await store.completeOnboarding(
      consent: ConsentRecord(
        coreData: true,
        aiFeatures: false,
        voiceRecording: false,
        recordedAt: DateTime.now().toUtc(),
      ),
      pin: '1234',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2019,
    );
    expect(todayQuestFor(store, child.id).done, 0);

    await store.recordLessonCompleted(
      childId: child.id,
      lessonId: 'a',
      scorePct: 100,
      timeSpentS: 30,
      xpEarned: 10,
    );
    await store.recordLessonCompleted(
      childId: child.id,
      lessonId: 'b',
      scorePct: 100,
      timeSpentS: 30,
      xpEarned: 10,
    );
    final q = todayQuestFor(store, child.id);
    expect(q.done, 2);
    expect(q.complete, isFalse);
    expect(q.remaining, 1);

    await store.recordLessonCompleted(
      childId: child.id,
      lessonId: 'c',
      scorePct: 100,
      timeSpentS: 30,
      xpEarned: 10,
    );
    expect(todayQuestFor(store, child.id).complete, isTrue);
  });

  test('subjectProgress is fraction completed', () {
    // Pure arithmetic path with empty store → 0.
    expect(
      subjectProgress(
        store: store,
        childId: 'x',
        stage: 1,
        subject: 'Math',
        items: const [(id: '1', type: 'lesson'), (id: '2', type: 'lesson')],
      ),
      0,
    );
  });
}
