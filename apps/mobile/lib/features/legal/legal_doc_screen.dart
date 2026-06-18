import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';

/// Renders a bundled legal document (privacy policy / terms) from
/// `assets/legal/*.md`. These are adult-facing and reached only through the
/// PIN-gated Parent Zone. The viewer is intentionally dependency-free: a small
/// Markdown-lite renderer covers the headings, callout, lists, and tables the
/// documents use, so we don't pull in a package for two static files.
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
              children: _MarkdownLite.render(context, snap.data!),
            );
          },
        ),
      ),
    );
  }
}

/// Minimal Markdown renderer for the subset our legal docs use.
class _MarkdownLite {
  static List<Widget> render(BuildContext context, String md) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];
    final lines = md.replaceAll('\r\n', '\n').split('\n');

    final quote = <String>[];
    final table = <String>[];

    void flushQuote() {
      if (quote.isEmpty) return;
      widgets.add(_callout(context, quote.join('\n')));
      quote.clear();
    }

    void flushTable() {
      if (table.isEmpty) return;
      widgets.add(_table(context, List.of(table)));
      table.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();

      if (line.startsWith('>')) {
        flushTable();
        quote.add(line.replaceFirst(RegExp(r'^>\s?'), ''));
        continue;
      }
      flushQuote();

      if (line.startsWith('|') && line.contains('|')) {
        table.add(line);
        continue;
      }
      flushTable();

      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 10));
      } else if (line.startsWith('### ')) {
        widgets.add(_heading(line.substring(4), 16, theme));
      } else if (line.startsWith('## ')) {
        widgets.add(_heading(line.substring(3), 18, theme));
      } else if (line.startsWith('# ')) {
        widgets.add(_heading(line.substring(2), 22, theme));
      } else if (line.trim() == '---') {
        widgets.add(const Divider(height: 28));
      } else if (RegExp(r'^[-*]\s').hasMatch(line.trim())) {
        widgets.add(_bullet(context, line.trim().replaceFirst(RegExp(r'^[-*]\s'), '')));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: _rich(context, line, height: 1.4),
        ));
      }
    }
    flushQuote();
    flushTable();
    return widgets;
  }

  static Widget _heading(String text, double size, ThemeData theme) => Padding(
        padding: EdgeInsets.only(top: size > 18 ? 8 : 14, bottom: 6),
        child: Text(
          _stripInline(text),
          style: TextStyle(
              fontSize: size, fontWeight: FontWeight.w800, color: WatotoColors.deep),
        ),
      );

  static Widget _bullet(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6, right: 8),
              child: Icon(Icons.circle, size: 6, color: WatotoColors.deep),
            ),
            Expanded(child: _rich(context, text, height: 1.4)),
          ],
        ),
      );

  static Widget _callout(BuildContext context, String text) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: WatotoColors.sun.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: WatotoColors.sun),
        ),
        child: _rich(context, text, height: 1.4),
      );

  static Widget _table(BuildContext context, List<String> rows) {
    // Drop the |---|---| separator row(s).
    final body = rows.where((r) => !RegExp(r'^\|[\s:\-|]+\|$').hasMatch(r)).toList();
    if (body.isEmpty) return const SizedBox.shrink();
    List<String> cells(String r) =>
        r.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < body.length; i++)
            Container(
              decoration: BoxDecoration(
                color: i == 0 ? WatotoColors.deep.withValues(alpha: 0.06) : null,
                border: i == 0
                    ? const Border(bottom: BorderSide(color: Colors.black12))
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in cells(body[i]))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          _stripInline(c),
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              fontWeight:
                                  i == 0 ? FontWeight.w700 : FontWeight.w400),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Renders inline `**bold**` segments; everything else is plain.
  static Widget _rich(BuildContext context, String text, {double height = 1.3}) {
    final base = DefaultTextStyle.of(context).style.copyWith(height: height);
    final spans = <TextSpan>[];
    var bold = false;
    for (final part in text.split('**')) {
      if (part.isNotEmpty) {
        spans.add(TextSpan(
            text: part,
            style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null));
      }
      bold = !bold;
    }
    return RichText(text: TextSpan(style: base, children: spans));
  }

  static String _stripInline(String s) => s.replaceAll('**', '');
}
