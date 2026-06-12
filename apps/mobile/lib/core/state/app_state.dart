import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active UI/content locale; one-click switching from the home screen.
final localeProvider = StateProvider<Locale>((_) => const Locale('en'));

/// Session XP balance. The real implementation is a drift-backed ledger
/// mirror synced to the API (docs/12-gamification.md); this provider keeps
/// the same read surface so screens won't change when that lands.
final xpProvider = StateProvider<int>((_) => 0);

/// Active child nickname placeholder until profiles land.
final activeChildNicknameProvider = Provider<String>((_) => 'Amani');
