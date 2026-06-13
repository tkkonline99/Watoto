import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active UI/content locale; one-click switching from the home screen.
final localeProvider = StateProvider<Locale>((_) => const Locale('en'));

/// Active child nickname placeholder until profiles land.
final activeChildNicknameProvider = Provider<String>((_) => 'Amani');
