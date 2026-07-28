import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';

/// Demo entrypoint (NOT shipped): seeds an onboarded family so the app boots
/// past onboarding for screenshots and manual exploration.
///
/// Uses the same [bootstrapWatoto] path as production so desktop/web demos
/// get auth, sync lifecycle, and Hive migration — not a stale mini-main.
///
///   flutter run -t lib/main_demo.dart -d windows
///   flutter run -t lib/main_demo.dart -d chrome --dart-define=START=/
Future<void> main() async {
  final container = await bootstrapWatoto(seedDemoFamily: true);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const WatotoApp(),
    ),
  );
}
