import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/offline/offline_providers.dart';
import '../features/auth/account_screen.dart';
import '../features/child_home/child_home_screen.dart';
import '../features/curriculum/curriculum_screen.dart';
import '../features/curriculum/subject_detail_screen.dart';
import '../features/legal/legal_doc_screen.dart';
import '../features/lesson_player/lesson_player_screen.dart';
import '../features/library/library_play_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/parent/parent_dashboard_screen.dart';
import '../features/parent/pin_gate_screen.dart';
import '../features/profiles/add_child_screen.dart';
import '../features/profiles/profile_picker_screen.dart';
import '../features/quiz/quiz_runner_screen.dart';
import '../features/stories/story_library_screen.dart';

/// Router is provided (not a global) so each app instance — and each widget
/// test — gets fresh navigation state. Guards enforce the deployment-required
/// flow (docs/05 §5.4): onboarding+consent first, parent zone behind the PIN,
/// a child must be selected before any learning surface.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  final sub = ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(() {
    sub.close();
    refresh.dispose();
  });

  return GoRouter(
    // Default '/'; a --dart-define=START=<route> allows deep-link launches
    // for demos and manual testing (guards still apply).
    initialLocation: const String.fromEnvironment('START', defaultValue: '/'),
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      final onboarding = loc.startsWith('/onboarding');

      if (!s.onboardingComplete) return onboarding ? null : '/onboarding';
      if (onboarding) return '/';

      if (loc.startsWith('/parent')) {
        if (loc == '/parent/pin') return null;
        // Account families are let straight in (no PIN). Otherwise PIN families
        // unlock with the PIN; a signed-out account family logs back in.
        if (s.parentAccessAllowed) return null;
        return ref.read(offlineStoreProvider).hasPin ? '/parent/pin' : '/account';
      }

      // Child surfaces require a selected profile; the picker is always allowed.
      if (loc.startsWith('/profiles')) return null;
      if (s.activeChildId == null) return '/profiles';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/profiles', builder: (c, s) => const ProfilePickerScreen()),
      GoRoute(path: '/profiles/add', builder: (c, s) => const AddChildScreen()),
      GoRoute(path: '/parent/pin', builder: (c, s) => const PinGateScreen()),
      GoRoute(path: '/parent', builder: (c, s) => const ParentDashboardScreen()),
      GoRoute(
        path: '/parent/legal/privacy',
        builder: (c, s) => const LegalDocScreen(doc: LegalDoc.privacy),
      ),
      GoRoute(
        path: '/parent/legal/terms',
        builder: (c, s) => const LegalDocScreen(doc: LegalDoc.terms),
      ),
      GoRoute(path: '/', builder: (c, s) => const ChildHomeScreen()),
      GoRoute(path: '/account', builder: (c, s) => const AccountScreen()),
      GoRoute(
        path: '/lesson/:slug',
        builder: (c, s) => LessonPlayerScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/quiz/:slug',
        builder: (c, s) => QuizRunnerScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(path: '/curriculum', builder: (c, s) => const CurriculumScreen()),
      GoRoute(
        path: '/subject/:stage/:name',
        builder: (c, s) => SubjectDetailScreen(
          stage: int.tryParse(s.pathParameters['stage'] ?? '') ?? 1,
          subject: Uri.decodeComponent(s.pathParameters['name'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/play/:id',
        builder: (c, s) => LibraryPlayScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/stories', builder: (c, s) => const StoryLibraryScreen()),
    ],
  );
});
