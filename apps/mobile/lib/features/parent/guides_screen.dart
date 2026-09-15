import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/watoto_theme.dart';
import '../../core/widgets/markdown_lite.dart';
import '../../core/widgets/watoto_status_views.dart';
import '../../l10n/gen/app_localizations.dart';

/// Curriculum guides for grown-ups — the full teaching packages behind the
/// app's playable content (lesson plans, worksheets, quizzes with answer
/// keys, reading-level guides, early-years development guides). Converted
/// from the source curriculum documents by tool/convert_guides.py and bundled
/// under assets/guides/; browsed from the PIN-gated Parent Zone.
class GuideDoc {
  const GuideDoc({
    required this.id,
    required this.title,
    required this.emoji,
    required this.asset,
  });

  final String id;
  final String title;
  final String emoji;
  final String asset;

  factory GuideDoc.fromJson(Map<String, dynamic> j) => GuideDoc(
    id: j['id'] as String,
    title: j['title'] as String,
    emoji: j['emoji'] as String? ?? '📄',
    asset: j['asset'] as String,
  );
}

class GuideGroup {
  const GuideGroup({
    required this.band,
    required this.title,
    required this.docs,
  });

  final String band;
  final String title;
  final List<GuideDoc> docs;

  factory GuideGroup.fromJson(Map<String, dynamic> j) => GuideGroup(
    band: j['band'] as String,
    title: j['title'] as String,
    docs: ((j['docs'] as List?) ?? const [])
        .map((d) => GuideDoc.fromJson(d as Map<String, dynamic>))
        .toList(),
  );
}

class GuidesRepository {
  GuidesRepository(this.groups)
    : byId = {
        for (final g in groups)
          for (final d in g.docs) d.id: d,
      };

  final List<GuideGroup> groups;
  final Map<String, GuideDoc> byId;

  static Future<GuidesRepository> load() async {
    final raw = await rootBundle.loadString(
      'assets/guides/guides_manifest.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final groups = ((json['groups'] as List?) ?? const [])
        .map((g) => GuideGroup.fromJson(g as Map<String, dynamic>))
        .toList();
    return GuidesRepository(groups);
  }
}

final guidesProvider = FutureProvider<GuidesRepository>(
  (_) => GuidesRepository.load(),
);

// ------------------------------------------------------------------- list

/// The guides library, grouped by age band. Parent Zone → Curriculum Guides.
class GuidesScreen extends ConsumerWidget {
  const GuidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final guidesAsync = ref.watch(guidesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.curriculumGuides)),
      body: SafeArea(
        child: guidesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (repo) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.curriculumGuidesIntro,
                  style: TextStyle(
                    fontSize: 14,
                    color: WatotoColors.deep.withValues(alpha: 0.7),
                  ),
                ),
              ),
              for (final group in repo.groups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 6),
                  child: Text(
                    group.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: WatotoColors.deep,
                    ),
                  ),
                ),
                for (final doc in group.docs)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      leading: Text(
                        doc.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        doc.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/parent/guides/${doc.id}'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- doc

/// A single guide, rendered with the shared Markdown-lite viewer.
class GuideDocScreen extends ConsumerWidget {
  const GuideDocScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guidesAsync = ref.watch(guidesProvider);
    return guidesAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (repo) {
        final doc = repo.byId[id];
        if (doc == null) {
          return const WatotoNotFoundScreen();
        }
        return Scaffold(
          appBar: AppBar(title: Text(doc.title)),
          body: SafeArea(
            child: FutureBuilder<String>(
              future: rootBundle.loadString(doc.asset),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: MarkdownLite.render(context, snap.data!),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
