import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/offline/offline_providers.dart';
import 'core/offline/offline_store.dart';
import 'features/onboarding/consent.dart';

/// Demo entrypoint (NOT shipped): seeds an onboarded family so the app boots
/// straight past onboarding, for screenshots and manual exploration. Pair
/// with `--dart-define=START=/some/route` to deep-link, e.g. /story/story-hare.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter('watoto_demo');
  final store = await OfflineStore.open();
  if (!store.onboardingComplete) {
    await store.completeOnboarding(
      consent: ConsentRecord(
        coreData: true,
        aiFeatures: true,
        voiceRecording: false,
        recordedAt: DateTime.now().toUtc(),
      ),
      pin: '1234',
      nickname: 'Amani',
      avatarKey: 'lion',
      birthYear: 2019,
    );
    // Seed some XP so the home screen looks alive in the demo.
    await store.recordLessonCompleted(
      childId: store.activeChildId!,
      lessonId: 'demo-seed',
      scorePct: 100,
      timeSpentS: 60,
      xpEarned: 20,
    );
  }
  final container = ProviderContainer(
    overrides: [offlineStoreProvider.overrideWithValue(store)],
  );
  runApp(UncontrolledProviderScope(container: container, child: const WatotoApp()));
}
