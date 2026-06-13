import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quiz_models.dart';

/// Offline-first quiz source — bundled sample packs now, drift/Hive cache
/// over the catalog API later, behind this same provider.
class QuizRepository {
  Future<QuizBody> load(String slug) async {
    final raw = await rootBundle.loadString('assets/content/$slug.json');
    return QuizBody.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

final quizRepositoryProvider = Provider<QuizRepository>((_) => QuizRepository());

final quizProvider = FutureProvider.family<QuizBody, String>(
  (ref, slug) => ref.watch(quizRepositoryProvider).load(slug),
);
