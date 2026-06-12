import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/child_home/child_home_screen.dart';
import '../features/lesson_player/lesson_player_screen.dart';

/// Router is provided (not a global) so each app instance — and each widget
/// test — gets fresh navigation state.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ChildHomeScreen(),
      ),
      GoRoute(
        path: '/lesson/:slug',
        builder: (context, state) =>
            LessonPlayerScreen(slug: state.pathParameters['slug']!),
      ),
    ],
  );
});
