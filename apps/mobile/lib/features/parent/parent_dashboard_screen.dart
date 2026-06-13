import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../l10n/gen/app_localizations.dart';

/// Parent dashboard: per-child progress, consent management, add child.
/// Reached only through the PIN gate (router guard).
class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.watch(sessionProvider); // rebuild after consent / profile changes
    final store = ref.watch(offlineStoreProvider);
    final children = ref.watch(childrenProvider);
    final consent = store.consent;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.parentZone),
        actions: [
          IconButton(
            tooltip: l10n.lockParentZone,
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(sessionProvider.notifier).lockParent();
              context.go('/');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.children, style: _section),
            const SizedBox(height: 8),
            for (final child in children)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: WatotoColors.sun,
                    child: Text(child.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  title: Text(child.nickname,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(l10n.ageBandLabel(child.ageBand.label)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${store.xpFor(child.id)} XP',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, color: WatotoColors.mango)),
                      Text(l10n.lessonsDone(store.completedLessonCount(child.id)),
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.addChild),
              onPressed: () => context.go('/profiles/add'),
            ),
            const Divider(height: 32),
            Text(l10n.privacyData, style: _section),
            const SizedBox(height: 8),
            SwitchListTile(
              value: consent.aiFeatures,
              title: Text(l10n.consentAi),
              subtitle: Text(l10n.consentAiBody),
              onChanged: (v) => ref
                  .read(sessionProvider.notifier)
                  .saveConsent(consent.copyWith(aiFeatures: v)),
            ),
            SwitchListTile(
              value: consent.voiceRecording,
              title: Text(l10n.consentVoice),
              subtitle: Text(l10n.consentVoiceBody),
              onChanged: (v) => ref
                  .read(sessionProvider.notifier)
                  .saveConsent(consent.copyWith(voiceRecording: v)),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.switch_account),
              title: Text(l10n.switchChild),
              onTap: () {
                ref.read(sessionProvider.notifier).lockParent();
                ref.read(sessionProvider.notifier).switchChild();
                context.go('/profiles');
              },
            ),
          ],
        ),
      ),
    );
  }

  static const _section =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: WatotoColors.deep);
}
