library;
import 'dart:convert';
import 'dart:io';
import 'package:watoto_mobile/features/library/step_visuals.dart';
import 'package:watoto_mobile/features/library/library_models.dart';
void main() {
  final root = jsonDecode(File('assets/content/watoto_content_library.json').readAsStringSync()) as Map<String, dynamic>;
  for (final raw in root['content'] as List<dynamic>) {
    final m = raw as Map<String, dynamic>;
    if (m['type'] != 'lesson') continue;
    final item = LibraryItem.fromJson(m);
    for (var i = 0; i < item.steps.length; i++) {
      final d = stepIllustrationDetail(item: item, narration: item.steps[i].narration);
      if (d.tier == IllustrationTier.subject) stdout.writeln('${item.id} step$i: "${item.steps[i].narration}"');
    }
  }
}
