import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active UI/content locale; one-click switching from the home screen.
/// The active child profile lives in `offline_providers.dart`
/// (`activeChildProvider`), seeded from the persisted store.
final localeProvider = StateProvider<Locale>((_) => const Locale('en'));
