import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lesson_models.dart';

/// Offline-first content source. The scaffold reads bundled sample packs;
/// the production repository layers drift/Hive caches over the catalog API
/// behind this same provider (docs/15-offline-sync.md).
class LessonRepository {
  Future<LessonBody> load(String slug) async {
    final raw = await rootBundle.loadString('assets/content/$slug.json');
    return LessonBody.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

final lessonRepositoryProvider = Provider<LessonRepository>((_) => LessonRepository());

final lessonProvider = FutureProvider.family<LessonBody, String>(
  (ref, slug) => ref.watch(lessonRepositoryProvider).load(slug),
);
