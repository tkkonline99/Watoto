import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/widgets/markdown_lite.dart';
import '../../l10n/gen/app_localizations.dart';

/// Renders a bundled legal document (privacy policy / terms) from
/// `assets/legal/*.md`. These are adult-facing and reached only through the
/// PIN-gated Parent Zone. Rendering is the shared [MarkdownLite] viewer.
enum LegalDoc { privacy, terms }

class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({super.key, required this.doc});

  final LegalDoc doc;

  String get _asset => switch (doc) {
    LegalDoc.privacy => 'assets/legal/privacy_policy.md',
    LegalDoc.terms => 'assets/legal/terms_of_service.md',
  };

  String _title(AppLocalizations l10n) => switch (doc) {
    LegalDoc.privacy => l10n.privacyPolicy,
    LegalDoc.terms => l10n.termsOfService,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_title(l10n))),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: rootBundle.loadString(_asset),
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
  }
}
