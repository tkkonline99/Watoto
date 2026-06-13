import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/offline/offline_providers.dart';
import 'core/offline/offline_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter('watoto');
  final store = await OfflineStore.open();

  final container = ProviderContainer(
    overrides: [offlineStoreProvider.overrideWithValue(store)],
  );
  // Best-effort: push progress recorded while offline. Never blocks startup.
  unawaited(container.read(syncEngineProvider).flush());

  runApp(UncontrolledProviderScope(container: container, child: const WatotoApp()));
}
