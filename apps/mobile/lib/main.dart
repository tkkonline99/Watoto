import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap.dart';

Future<void> main() async {
  final container = await bootstrapWatoto();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const WatotoApp(),
    ),
  );
}
