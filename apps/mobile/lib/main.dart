import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/offline/offline_providers.dart';
import 'core/offline/offline_store.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter('watoto');
  final store = await OfflineStore.open();

  final container = ProviderContainer(
    overrides: [offlineStoreProvider.overrideWithValue(store)],
  );
  // Start an anonymous session so a child can play immediately (auth.ts design);
  // upgraded in place when a parent signs up. Local until Firebase is wired.
  unawaited(container.read(authServiceProvider).ensureAnonymousSession());
  // Best-effort: push progress recorded while offline. Never blocks startup.
  unawaited(container.read(syncEngineProvider).flush());

  runApp(UncontrolledProviderScope(container: container, child: const WatotoApp()));
}
