import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'whats_new.dart';

/// Parent-facing release notes (not shown mid-activity to kids).
class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.whatsNewTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              l10n.whatsNewSubtitle(appWhatsNewVersion),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: WatotoColors.deep.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            for (final release in whatsNewReleases) ...[
              Card(
                elevation: 0,
                color: WatotoColors.sun.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: WatotoColors.sun.withValues(alpha: 0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: WatotoColors.mango,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'v${release.version}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              release.title,
                              style: const TextStyle(
                                fontFamily: 'Baloo2',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: WatotoColors.deep,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final b in release.bullets) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('✨ ', style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: Text(
                                b,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              l10n.whatsNewFooter,
              style: TextStyle(
                fontSize: 12,
                color: WatotoColors.deep.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
