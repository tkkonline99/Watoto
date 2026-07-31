import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/offline/offline_providers.dart';
import '../features/auth/account_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/password_reset_screen.dart';
import '../features/auth/paywall_screen.dart';
import '../features/auth/pin_reset_screen.dart';
import '../features/child_home/child_home_screen.dart';
import '../features/curriculum/curriculum_screen.dart';
import '../features/curriculum/subject_detail_screen.dart';
import '../features/gamification/avatar_shop_screen.dart';
import '../features/gamification/certificate_screen.dart';
import '../features/legal/legal_doc_screen.dart';
import '../features/lesson_player/lesson_player_screen.dart';
import '../features/library/library_play_screen.dart';
import '../features/onboarding/language_select_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/parent/guides_screen.dart';
import '../features/parent/parent_dashboard_screen.dart';
import '../features/parent/pin_gate_screen.dart';
import '../features/parent/rest_screen.dart';
import '../features/profiles/add_child_screen.dart';
import '../features/profiles/profile_picker_screen.dart';
import '../features/quiz/quiz_runner_screen.dart';
import '../features/stories/story_library_screen.dart';
import 'return_to.dart';
import '../core/offline/offline_store.dart';

/// Lets a widget test start on a post-login surface without driving `/login`
/// first. Tests that exercise the gate itself leave it false.
@visibleForTesting
bool debugSkipLoginGate = false;

/// Router is provided (not a global) so each app instance — and each widget
/// test — gets fresh navigation state. Guards enforce the deployment-required
/// flow (docs/05 §5.4): onboarding+consent first, a login every run, parent
/// zone behind the PIN, a child selected before any learning surface.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  final sub = ref.listen(sessionProvider, (_, _) => refresh.value++);
  final sub2 = ref.listen(screenTimeTickProvider, (_, _) => refresh.value++);
  ref.onDispose(() {
    sub.close();
    sub2.close();
    refresh.dispose();
  });

  return GoRouter(
    // Open on the welcome / "Choose your language" landing; "Let's go" enters
    // the home. A --dart-define=START=<route> overrides for demos/testing.
    initialLocation: const String.fromEnvironment(
      'START',
      defaultValue: '/welcome',
    ),
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      final onboarding = loc.startsWith('/onboarding');

      if (!s.onboardingComplete) return onboarding ? null : '/onboarding';
      if (onboarding) return '/';

      // The welcome/landing screen is always reachable once onboarded.
      if (loc == '/welcome') return null;

      // Recovery is always reachable. These deliberately sit outside /parent
      // *and* outside the login gate: a grown-up who has forgotten the PIN
      // cannot be asked to pass the gate they are trying to reset, and a
      // family whose password is gone could otherwise never get past /login.
      // Both screens run their own adult check (parent gate, and an emailed
      // code) before changing anything.
      if (loc == '/pin-reset' || loc == '/password-reset') return null;

      // Nothing else opens until the family has logged in *this run*. Watoto
      // keeps no session across launches, so this is the front door on every
      // start, not just the first one.
      if (!s.authenticated && !debugSkipLoginGate) {
        if (loc == '/login') return null;
        return gateWithReturn('/login', state.uri.toString());
      }
      // Already in — the login screen has nothing left to say.
      if (loc == '/login') return '/';

      if (loc.startsWith('/parent') || loc == '/paywall') {
        if (loc == '/parent/pin') return null;
        // Account families are let straight in (no PIN). Otherwise PIN families
        // unlock with the PIN; a signed-out account family logs back in.
        if (s.parentAccessAllowed) return null;
        // Carry the full intended location (query included) through the gate,
        // so unlocking hands the family back to the activity they came for
        // instead of stranding them on the dashboard.
        final intended = state.uri.toString();
        return ref.read(offlineStoreProvider).hasPin
            ? gateWithReturn('/parent/pin', intended)
            : gateWithReturn('/login', intended);
      }

      if (loc == '/rest') return null;

      // Child surfaces require a selected profile; the picker is always allowed.
      if (loc.startsWith('/profiles')) return null;
      if (s.activeChildId == null) return '/profiles';

      // Soft screen-time lock on child learning surfaces.
      final store = ref.read(offlineStoreProvider);
      final learning = loc == '/' ||
          loc.startsWith('/play') ||
          loc.startsWith('/subject') ||
          loc.startsWith('/stories') ||
          loc.startsWith('/lesson') ||
          loc.startsWith('/quiz') ||
          loc.startsWith('/shop');
      if (learning && store.isScreenTimeExceeded()) return '/rest';

      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(
        path: '/profiles',
        builder: (c, s) => const ProfilePickerScreen(),
      ),
      GoRoute(path: '/profiles/add', builder: (c, s) => const AddChildScreen()),
      GoRoute(path: '/parent/pin', builder: (c, s) => const PinGateScreen()),
      GoRoute(path: '/pin-reset', builder: (c, s) => const PinResetScreen()),
      GoRoute(
        path: '/password-reset',
        builder: (c, s) => const PasswordResetScreen(),
      ),
      GoRoute(
        path: '/parent',
        builder: (c, s) => const ParentDashboardScreen(),
      ),
      GoRoute(path: '/parent/guides', builder: (c, s) => const GuidesScreen()),
      GoRoute(
        path: '/parent/guides/:id',
        builder: (c, s) => GuideDocScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/parent/legal/privacy',
        builder: (c, s) => const LegalDocScreen(doc: LegalDoc.privacy),
      ),
      GoRoute(
        path: '/parent/legal/terms',
        builder: (c, s) => const LegalDocScreen(doc: LegalDoc.terms),
      ),
      GoRoute(path: '/paywall', builder: (c, s) => const PaywallScreen()),
      GoRoute(path: '/rest', builder: (c, s) => const RestScreen()),
      GoRoute(path: '/shop', builder: (c, s) => const AvatarShopScreen()),
      GoRoute(
        path: '/certificate',
        builder: (c, s) => const CertificateScreen(),
      ),
      GoRoute(path: '/', builder: (c, s) => const ChildHomeScreen()),
      GoRoute(path: '/welcome', builder: (c, s) => const WelcomeScreen()),
      GoRoute(path: '/account', builder: (c, s) => const AccountScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
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
