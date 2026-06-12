# 5. Flutter Project Structure

Feature-first Clean-ish architecture: each feature owns `data / domain / presentation`; shared infrastructure lives in `core/`. Riverpod for state, GoRouter for navigation, drift (SQLite) for relational offline data, Hive for key-value caches.

## 5.1 Directory Layout (`apps/mobile/`)

```
lib/
├── main_dev.dart / main_staging.dart / main_prod.dart   # flavor entrypoints
├── app.dart                       # MaterialApp.router, theme, locale wiring
├── bootstrap.dart                 # Firebase init, Hive/drift init, Crashlytics zone
│
├── core/
│   ├── config/                    # AppConfig per flavor (apiBaseUrl, etc.)
│   ├── network/                   # dio client, auth interceptor, retry, ETag cache
│   ├── auth/                      # session controller, token storage (flutter_secure_storage)
│   ├── db/                        # drift database, DAOs, migrations
│   │   ├── app_db.dart
│   │   └── tables/ (progress, sync_queue, downloads, balances)
│   ├── storage/                   # Hive boxes: settings, catalog cache, media index
│   ├── sync/                      # SyncEngine, ConnectivityWatcher, op queue
│   ├── downloads/                 # DownloadManager (manifests, resumable, integrity)
│   ├── audio/                     # AudioService wrapper over just_audio, ducking, TTS playback
│   ├── analytics/                 # typed analytics events → Firebase Analytics
│   ├── l10n/                      # arb/, generated AppLocalizations, LocaleController
│   │   └── arb/ app_en.arb, app_sw.arb, app_fr.arb
│   ├── theme/                     # design tokens, age-band themes, dyslexic font toggle
│   ├── a11y/                      # semantics helpers, text-scale clamps, contrast mode
│   ├── widgets/                   # WatotoButton, WatotoCard, MascotWidget, ProgressRing...
│   └── utils/
│
├── features/
│   ├── onboarding/                # splash, language pick, parent signup, child setup
│   ├── child_home/                # age-banded home, subject islands, daily challenge
│   ├── lesson_player/             # block renderer engine for lesson body JSON
│   │   ├── presentation/blocks/   # one widget per block type (concept, tap_to_count, check…)
│   ├── quiz/                      # quiz runner, per-question widgets, results + rewards
│   ├── stories/                   # library, reader (page view, narration, word highlight)
│   ├── games/                     # game launcher + builtin engines (match, trace, sort, memory)
│   ├── flashcards/                # deck browser, flip/swipe player
│   ├── rewards/                   # balances, badges, avatar shop, certificates
│   ├── ai_tutor/                  # chat-style tutor UI (child-safe, SSE stream)
│   ├── reading_coach/             # record → upload → score UI
│   ├── parent_zone/               # PIN gate, dashboard, reports, screen time, children mgmt
│   ├── subscription/              # paywall, plans, IAP (in_app_purchase) + Stripe web
│   ├── teacher/                   # groups, assignments, class analytics (tablet/web first)
│   └── settings/                  # locale, a11y, downloads manager, legal
│
└── router/
    ├── app_router.dart            # GoRouter config + guards
    └── routes.dart                # typed route names

test/                              # mirrors lib/ structure
integration_test/
```

## 5.2 Key Packages (`pubspec.yaml` excerpt)

```yaml
dependencies:
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
  go_router: ^14.0.0
  dio: ^5.4.0
  drift: ^2.18.0
  hive_flutter: ^1.1.0
  flutter_secure_storage: ^9.0.0
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  firebase_analytics: ^11.0.0
  firebase_crashlytics: ^4.0.0
  firebase_messaging: ^15.0.0
  just_audio: ^0.9.38
  video_player: ^2.8.0
  rive: ^0.13.0
  lottie: ^3.1.0
  in_app_purchase: ^6.0.0
  record: ^5.0.0            # reading coach mic capture
  intl: any                 # via flutter_localizations
  connectivity_plus: ^6.0.0
  cached_network_image: ^3.3.0
dev_dependencies:
  build_runner: ^2.4.0
  riverpod_generator: ^2.4.0
  drift_dev: ^2.18.0
  mocktail: ^1.0.0
  golden_toolkit: ^0.15.0
```

## 5.3 State Management Pattern

```dart
// features/lesson_player/presentation/lesson_controller.dart
@riverpod
class LessonController extends _$LessonController {
  @override
  Future<LessonState> build(String lessonId) async {
    final repo = ref.watch(lessonRepositoryProvider);
    // Offline-first: local DB hit first, network refresh in background
    final lesson = await repo.getLesson(lessonId);
    return LessonState.playing(lesson: lesson, blockIndex: 0);
  }

  Future<void> completeBlock(BlockResult result) async { /* advance, record */ }

  Future<void> finishLesson() async {
    final s = state.requireValue;
    await ref.read(progressRepositoryProvider).recordCompletion(
      lessonId: s.lesson.id, scorePct: s.score,
      timeSpentS: s.elapsed.inSeconds,
    ); // writes drift row + enqueues sync op atomically
    await ref.read(rewardServiceProvider).grant(s.lesson.completionRewards);
    state = AsyncData(s.copyWith(phase: LessonPhase.celebration));
  }
}
```

Repository rule: **every repository reads local first** (drift/Hive), returns immediately, and triggers a background refresh that updates the local store; UI rebuilds reactively via drift streams → providers. Writes always land locally + enqueue a sync op in the same transaction.

## 5.4 Routing & Guards (GoRouter)

```dart
final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (ctx, state) {
    final session = ref.read(sessionProvider);
    if (!session.bootstrapped) return '/splash';
    if (session.isChildLocked && state.matchedLocation.startsWith('/parent')) {
      return '/parent/pin';                       // PIN gate for parent zone
    }
    if (session.activeChild == null && _needsChild(state)) return '/profiles';
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: ...),
    GoRoute(path: '/onboarding', routes: [language, parentAuth, consent, childSetup]),
    GoRoute(path: '/profiles', builder: ...),     // "who's learning?" picker
    StatefulShellRoute.indexedStack(              // child shell: Home / Stories / Games / Rewards
      branches: [home, stories, games, rewards],
    ),
    GoRoute(path: '/lesson/:id', builder: ...),
    GoRoute(path: '/quiz/:id', builder: ...),
    GoRoute(path: '/story/:id/read', builder: ...),
    GoRoute(path: '/parent', routes: [pin, dashboard, childMgmt, reports, screenTime, subscription, settings]),
    GoRoute(path: '/teacher', routes: [groups, assignments, analytics]),
  ],
);
```

## 5.5 Localization

- ARB files per locale in `core/l10n/arb/`; `flutter gen-l10n` generates `AppLocalizations`.
- **UI strings**: ARB. **Content strings**: server `translations` delivered inside content payloads (already resolved for `Accept-Language`), cached offline with the content pack.
- `LocaleController` persists choice in Hive; one-click switch re-resolves content from local packs when available, else refetches.
- Every content string key can carry `audioUrl` → tap-to-hear pronunciation via `AudioService`.

## 5.6 Offline Storage Split

| Store | Used for |
|-------|----------|
| drift (SQLite) | progress, quiz attempts, reward ledger mirror, sync queue, download registry, flashcard SRS state |
| Hive | settings, session, catalog JSON cache, small KV |
| File system (`path_provider`) | downloaded media packs `packs/<scope>/<hash>/...` (images, audio, video, rive) |
| flutter_secure_storage | refresh token, PIN-unlock state |

## 5.7 Platform Notes

- **Web**: drift via `drift/wasm` (sqlite3.wasm + OPFS); media packs limited (no large video pre-downloads); IAP replaced by Stripe Checkout redirect.
- **Flavors**: `--flavor dev|staging|prod` with separate Firebase projects and bundle IDs (`app.watoto.dev`, `app.watoto.stg`, `app.watoto`).
- **Child UI hard rules** enforced by lint + review: no external `url_launcher` in child features, no text input fields exposed to children except sandboxed creativity activities, minimum tap target 48dp (64dp in 0–2 band).
