import 'dart:convert';

import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics.dart';
import '../../core/audio/narration.dart';
import '../../core/l10n/store_error_text.dart';
import '../../core/offline/desktop_export_stub.dart'
    if (dart.library.io) '../../core/offline/desktop_export_io.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/offline/offline_store.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../data/cloud/cloud_sync.dart';
import '../../domain/models/child_profile.dart';
import '../../features/auth/entitlements.dart';
import '../../features/auth/parent_gate_dialog.dart';
import '../../features/gamification/achievements_sheet.dart';
import '../../features/gamification/badge_stats_source.dart';
import '../../features/gamification/rewards.dart';
import '../../l10n/gen/app_localizations.dart';
import 'family_layer.dart';
import 'parent_insights.dart';
import 'reminders/reminder_service.dart';
import 'weekly_snapshot.dart';

/// A goal the whole household shares this week.
///
/// Shared rather than competitive on purpose (docs/12 §12.5): siblings pulling
/// toward one number cannot produce a loser, which a leaderboard always does.
class _FamilyChallengeCard extends ConsumerWidget {
  const _FamilyChallengeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.watch(economyTickProvider);
    final store = ref.watch(offlineStoreProvider);
    final challenge = familyChallengeFor(store);
    if (store.children.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  challenge.complete ? '🏆' : '🎯',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.familyChallenge,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  '${challenge.done}/${challenge.goal}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: challenge.progress,
                minHeight: 10,
                backgroundColor: WatotoColors.sun.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(
                  challenge.complete ? WatotoColors.leaf : WatotoColors.mango,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              challenge.complete
                  ? l10n.familyChallengeDone
                  : l10n.familyChallengeBody(challenge.remaining),
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets a grown-up leave a message the child meets next time they open the
/// app. A fixed set of phrases — never free text — keeps this safe by
/// construction and takes one tap.
class _SendCheerRow extends ConsumerWidget {
  const _SendCheerRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final child = ref.watch(activeChildProvider);
    if (child == null) return const SizedBox.shrink();
    final store = ref.watch(offlineStoreProvider);

    Future<void> send(CheerKind kind) async {
      await store.sendCheer(
        child.id,
        encodeCheer(kind, DateTime.now()),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cheerSent(child.nickname))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sendCheer(child.nickname),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.sendCheerBody,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in allCheers)
              ActionChip(
                avatar: Text(cheerEmoji(kind)),
                label: Text(
                  switch (kind) {
                    CheerKind.proud => l10n.cheerProud,
                    CheerKind.wow => l10n.cheerWow,
                    CheerKind.keepGoing => l10n.cheerKeepGoing,
                    CheerKind.loveIt => l10n.cheerLoveIt,
                  },
                ),
                onPressed: () => send(kind),
              ),
          ],
        ),
      ],
    );
  }
}

/// Practice reminders — parent-facing and opt-in (docs/12 §12.6). Nothing is
/// ever pushed to a child, and nothing is scheduled until this is switched on.
class _RemindersSection extends ConsumerStatefulWidget {
  const _RemindersSection();

  @override
  ConsumerState<_RemindersSection> createState() => _RemindersSectionState();
}

class _RemindersSectionState extends ConsumerState<_RemindersSection> {
  bool? _supported;
  String? _note;

  @override
  void initState() {
    super.initState();
    // Probe once: web and desktop-without-a-notifier say no, and the row
    // explains itself rather than offering a switch that cannot work.
    ref
        .read(reminderServiceProvider)
        .isSupported()
        .then((value) {
      if (mounted) setState(() => _supported = value);
    });
  }

  Future<void> _toggle(bool on) async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(reminderServiceProvider);
    final achieved = await service.setEnabled(on, l10n: l10n);
    if (!mounted) return;
    setState(() {
      // Asking for `on` and getting `false` back means the OS refused.
      _note = (on && !achieved) ? l10n.remindersDenied : null;
    });
    ref.read(reminderTickProvider.notifier).state++;
  }

  Future<void> _pickTime() async {
    final l10n = AppLocalizations.of(context);
    final store = ref.read(offlineStoreProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: store.reminderHour,
        minute: store.reminderMinute,
      ),
    );
    if (picked == null || !mounted) return;
    await ref
        .read(reminderServiceProvider)
        .setTime(picked.hour, picked.minute, l10n: l10n);
    if (!mounted) return;
    ref.read(reminderTickProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.watch(reminderTickProvider);
    final store = ref.watch(offlineStoreProvider);
    final enabled = store.remindersEnabled;
    final supported = _supported;

    if (supported == false) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.notifications_off_outlined),
        title: Text(l10n.remindersTitle),
        subtitle: Text(l10n.remindersUnsupported),
      );
    }

    final time = TimeOfDay(
      hour: store.reminderHour,
      minute: store.reminderMinute,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          title: Text(l10n.remindersTitle),
          subtitle: Text(l10n.remindersBody),
          // Null while the platform probe is in flight.
          onChanged: supported == null ? null : _toggle,
        ),
        if (enabled)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: Text(l10n.reminderTimeLabel),
            subtitle: Text(time.format(context)),
            onTap: _pickTime,
          ),
        if (_note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _note!,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ),
      ],
    );
  }
}

Future<void> _editNickname(
  BuildContext context,
  WidgetRef ref,
  ChildProfile child,
) async {
  final l10n = AppLocalizations.of(context);
  final store = ref.read(offlineStoreProvider);
  if (!store.canEditChildNickname(child.id)) {
    final days =
        nicknameCooldownDaysRemaining(child.nicknameChangedAt);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.nicknameCooldown(days))),
      );
    }
    return;
  }
  final controller = TextEditingController(text: child.nickname);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.editNicknameTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.editNicknameBody),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.childNickname,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.save),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) {
    controller.dispose();
    return;
  }
  try {
    await store.updateChildNickname(
      childId: child.id,
      nickname: controller.text,
    );
    // The name itself is child PII and never leaves the device — only the
    // fact that a rename happened is recorded.
    ref.read(analyticsProvider).log(AnalyticsEvents.nicknameChange);
    ref.read(sessionProvider.notifier).touchProfiles();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.nicknameUpdated)),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            storeErrorText(l10n, e, fallback: l10n.nicknameUpdateFailed),
          ),
        ),
      );
    }
  } finally {
    controller.dispose();
  }
}

String _insightHeadline(AppLocalizations l10n, ParentInsight insight) =>
    switch (insight.kind) {
      InsightKind.quietWeek => l10n.insightQuietWeek,
      InsightKind.strongWeek => l10n.insightStrongWeek,
      InsightKind.streak => l10n.insightStreak(insight.days),
      InsightKind.stars => l10n.insightStars,
      InsightKind.oneDay => l10n.insightOneDay,
    };

String _insightDetail(
  AppLocalizations l10n,
  ParentInsight insight,
  String nickname,
) =>
    switch (insight.kind) {
      InsightKind.quietWeek => l10n.insightQuietWeekDetail(nickname),
      InsightKind.strongWeek =>
        l10n.insightStrongWeekDetail(nickname, insight.count),
      InsightKind.streak => l10n.insightStreakDetail,
      InsightKind.stars => l10n.insightStarsDetail(insight.count),
      InsightKind.oneDay => l10n.insightOneDayDetail,
    };

/// Tells a parent why the app went quiet.
///
/// Swahili in particular ships on very few devices, so an audio-first family
/// could open the app and simply get silence with no explanation. Shows only
/// once the engine has actually been probed and come back empty.
class _NarrationAvailabilityNotice extends ConsumerWidget {
  const _NarrationAvailabilityNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final narration = ref.watch(narrationProvider.notifier);
    if (!ref.watch(narrationProvider) || !narration.isKnownUnavailable(lang)) {
      return const SizedBox.shrink();
    }
    final languageName = switch (lang) {
      'sw' => 'Kiswahili',
      'fr' => 'Français',
      _ => 'English',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Semantics(
        container: true,
        label: '${l10n.narrationUnavailableTitle}. '
            '${l10n.narrationUnavailableBody(languageName)}',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WatotoColors.sun.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.volume_off_outlined, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.narrationUnavailableTitle,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(l10n.narrationUnavailableBody(languageName)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Restore a previously exported backup.
///
/// This build keeps everything on device, so a reinstall or a lost phone used
/// to mean a child started from zero — the export existed but nothing could
/// read it back. Paste-based rather than file-picker-based so it works
/// identically on web, mobile and desktop without another plugin.
Future<void> _restoreBackupFlow(
  BuildContext context,
  WidgetRef ref,
  OfflineStore store,
) async {
  final l10n = AppLocalizations.of(context);
  if (!await showParentGateDialog(context, ref)) return;
  if (!context.mounted) return;

  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.restoreBackup),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.restoreBackupPaste),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 5,
            minLines: 3,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.restoreBackupAction),
        ),
      ],
    ),
  );

  final raw = controller.text;
  controller.dispose();
  if (confirmed != true || raw.trim().isEmpty) return;

  String message;
  var restored = false;
  try {
    final result = await restoreFamilyBackup(store, raw);
    restored = !result.isEmpty;
    message = result.isEmpty
        ? l10n.restoreBackupNothing
        : l10n.restoreBackupDone(
            result.childrenRestored,
            result.progressRestored,
          );
  } on FormatException {
    message = l10n.restoreBackupInvalid;
  }

  ref.read(analyticsProvider).log(AnalyticsEvents.backupRestore, {
    'restored': restored,
  });
  if (restored) {
    // Profiles and balances changed underneath the UI.
    ref.read(sessionProvider.notifier).touchProfiles();
    ref.read(economyTickProvider.notifier).state++;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _SyncStatusCard extends ConsumerWidget {
  const _SyncStatusCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(syncEngineProvider);
    final pending = engine.pendingCount;
    final err = engine.lastError;
    final message = err != null
        ? l10n.syncStatusError
        : pending > 0
            ? l10n.syncStatusPending(pending)
            : l10n.syncStatusOk;
    return Card(
      child: ListTile(
        leading: Icon(
          err != null
              ? Icons.cloud_off_rounded
              : pending > 0
                  ? Icons.cloud_upload_rounded
                  : Icons.cloud_done_rounded,
          color: WatotoColors.sky,
        ),
        title: Text(message),
      ),
    );
  }
}

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
    final textScale = ref.watch(textScaleProvider);

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
            Text(l10n.weeklySnapshot, style: _section),
            const SizedBox(height: 8),
            for (final child in children)
              _WeeklyCard(
                nickname: child.nickname,
                emoji: child.emoji,
                snap: weeklySnapshotFor(store, child.id),
                l10n: l10n,
              ),
            if (children.isEmpty)
              Text(
                l10n.weeklySnapshotEmpty,
                style: const TextStyle(color: Colors.black54),
              ),
            const SizedBox(height: 16),
            Text(l10n.parentInsights, style: _section),
            const SizedBox(height: 8),
            for (final child in children)
              for (final insight in buildParentInsights(
                store: store,
                childId: child.id,
                nickname: child.nickname,
              ))
                Card(
                  child: ListTile(
                    leading: Text(
                      insight.tone == 'cheer'
                          ? '🌟'
                          : insight.tone == 'nudge'
                              ? '💡'
                              : '📋',
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(
                      '${child.nickname}: ${_insightHeadline(l10n, insight)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      _insightDetail(l10n, insight, child.nickname),
                    ),
                  ),
                ),
            if (children.isEmpty)
              Text(
                l10n.parentInsightsEmpty,
                style: const TextStyle(color: Colors.black54),
              ),
            const SizedBox(height: 16),
            _SyncStatusCard(l10n: l10n),
            const Divider(height: 32),
            Text(l10n.children, style: _section),
            const SizedBox(height: 8),
            for (final child in children)
              Builder(
                builder: (context) {
                  final xp = store.xpFor(child.id);
                  final stats = badgeStatsFor(store, child.id);
                  final badges = earnedBadges(stats);
                  final stars = store.totalStars(child.id);
                  final coins = store.coinsFor(child.id);
                  return Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: WatotoColors.sun,
                            child: Text(
                              child.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                          title: Text(
                            child.nickname,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${l10n.ageBandLabel(child.ageBand.label)} · '
                            '${l10n.levelLabel(stats.level)}',
                          ),
                          onLongPress: () => _editNickname(context, ref, child),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l10n.editNicknameTitle,
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () =>
                                    _editNickname(context, ref, child),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$xp XP · ${'⭐' * (stars.clamp(0, 3) == 0 ? 0 : 1)}$stars',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: WatotoColors.mango,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${l10n.lessonsDone(store.completedLessonCount(child.id))} · 🪙 $coins',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: badges.isEmpty
                                ? Text(
                                    l10n.noBadgesYet,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      for (final b in badges)
                                        Tooltip(
                                          message: badgeLabel(l10n, b.id),
                                          child: Text(
                                            b.emoji,
                                            style: const TextStyle(
                                              fontSize: 22,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.addChild),
              onPressed: () => context.go('/profiles/add'),
            ),
            const Divider(height: 32),
            Text(l10n.screenTime, style: _section),
            const SizedBox(height: 8),
            Text(
              l10n.screenTimeBody,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final mins in const [0, 15, 25, 45])
                  ChoiceChip(
                    label: Text(
                      mins == 0
                          ? l10n.screenTimeOff
                          : l10n.screenTimeMinutes(mins),
                    ),
                    selected: store.screenTimeLimitMinutes() == mins,
                    onSelected: (_) async {
                      await store.setScreenTimeLimitMinutes(mins);
                      ref.read(screenTimeTickProvider.notifier).state++;
                    },
                  ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_outlined),
              title: Text(l10n.screenTimeUsed(
                store.screenTimeUsedSeconds() ~/ 60,
              )),
              trailing: TextButton(
                onPressed: () async {
                  await store.grantScreenTimeGrace(minutes: 10);
                  ref.read(screenTimeTickProvider.notifier).state++;
                },
                child: Text(l10n.restGrace),
              ),
            ),
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                ref.watch(isPremiumProvider)
                    ? Icons.workspace_premium
                    : Icons.workspace_premium_outlined,
                color: WatotoColors.mango,
              ),
              title: Text(l10n.premiumTitle),
              subtitle: Text(
                freePremiumMapSummary(
                  isPremium: ref.watch(isPremiumProvider),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/paywall'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.military_tech_outlined),
              title: Text(l10n.certificateTitle),
              subtitle: Text(l10n.certificateSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                if (ref.read(activeChildProvider) == null &&
                    children.isNotEmpty) {
                  await ref
                      .read(sessionProvider.notifier)
                      .selectChild(children.first.id);
                }
                if (context.mounted) context.push('/certificate');
              },
            ),
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(l10n.curriculumGuides),
              subtitle: Text(l10n.curriculumGuidesBody),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/parent/guides'),
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: ref.watch(analyticsOptInProvider),
              title: Text(l10n.analyticsOptIn),
              subtitle: Text(l10n.analyticsOptInBody),
              onChanged: (v) =>
                  ref.read(analyticsOptInProvider.notifier).set(v),
            ),
            const Divider(height: 32),
            Text(l10n.accessibility, style: _section),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.format_size, color: WatotoColors.deep),
                const SizedBox(width: 12),
                Text(
                  l10n.textSize,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _sizeChip(ref, l10n.textSizeSmall, 1.0, textScale),
                _sizeChip(ref, l10n.textSizeMedium, 1.3, textScale),
                _sizeChip(ref, l10n.textSizeLarge, 1.6, textScale),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: ref.watch(narrationProvider),
              title: Text(l10n.readAloud),
              subtitle: Text(l10n.readAloudBody),
              onChanged: (_) => ref.read(narrationProvider.notifier).toggle(),
            ),
            const _NarrationAvailabilityNotice(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: ref.watch(dyslexiaFriendlyProvider),
              title: Text(l10n.readingEase),
              subtitle: Text(l10n.readingEaseBody),
              onChanged: (v) =>
                  ref.read(dyslexiaFriendlyProvider.notifier).set(v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: ref.watch(highContrastProvider),
              title: Text(l10n.highContrast),
              subtitle: Text(l10n.highContrastBody),
              onChanged: (v) =>
                  ref.read(highContrastProvider.notifier).set(v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: ref.watch(reducedMotionProvider),
              title: Text(l10n.reducedMotion),
              subtitle: Text(l10n.reducedMotionBody),
              onChanged: (v) =>
                  ref.read(reducedMotionProvider.notifier).set(v),
            ),
            const Divider(height: 32),
            const _FamilyChallengeCard(),
            const SizedBox(height: 12),
            const _SendCheerRow(),
            const Divider(height: 32),
            const _RemindersSection(),
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.download_outlined),
              title: Text(l10n.exportData),
              subtitle: Text(l10n.exportDataBody),
              onTap: () async {
                if (!await showParentGateDialog(context, ref)) return;
                if (!context.mounted) return;
                // Portable backup (reinstall handoff) + human-readable export.
                final backup = buildFamilyBackup(store);
                final json = const JsonEncoder.withIndent('  ')
                    .convert(store.exportFamilyData());
                final bundle = '${backup.toJsonString()}\n---\n$json';
                await Clipboard.setData(ClipboardData(text: bundle));
                // On Windows/macOS/Linux also write a file parents can open.
                final path = await writeFamilyExportFile(bundle);
                ref.read(analyticsProvider).log(AnalyticsEvents.exportData);
                ref.read(analyticsProvider).log(AnalyticsEvents.backupExport, {
                  'children': children.length,
                  'toFile': path != null,
                });
                if (!context.mounted) return;
                final msg = path == null
                    ? l10n.exportDataCopied
                    : '${l10n.exportDataCopied}\n$path';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg)),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.upload_outlined),
              title: Text(l10n.restoreBackup),
              subtitle: Text(l10n.restoreBackupBody),
              onTap: () => _restoreBackupFlow(context, ref, store),
            ),
            for (final child in children)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text(l10n.deleteChild(child.nickname)),
                subtitle: Text(l10n.deleteChildBody),
                onTap: () async {
                  if (!await showParentGateDialog(context, ref)) return;
                  if (!context.mounted) return;
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.deleteChild(child.nickname)),
                      content: Text(l10n.deleteChildConfirm),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await store.deleteChild(child.id);
                  ref.read(sessionProvider.notifier).touchProfiles();
                  if (ref.read(sessionProvider).activeChildId == child.id) {
                    ref.read(sessionProvider.notifier).switchChild();
                  }
                },
              ),
            const Divider(height: 32),
            Text(l10n.legalSection, style: _section),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.privacyPolicy),
              subtitle: Text(l10n.legalDraftNote),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/parent/legal/privacy'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.termsOfService),
              subtitle: Text(l10n.legalDraftNote),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/parent/legal/terms'),
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

  static const _section = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: WatotoColors.deep,
  );
}

/// A selectable text-size chip; [value] is the multiplier it applies.
Widget _sizeChip(WidgetRef ref, String label, double value, double current) {
  return ChoiceChip(
    label: Text(label),
    selected: (current - value).abs() < 0.01,
    onSelected: (_) => ref.read(textScaleProvider.notifier).set(value),
  );
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({
    required this.nickname,
    required this.emoji,
    required this.snap,
    required this.l10n,
  });

  final String nickname;
  final String emoji;
  final WeeklySnapshot snap;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final summary = snap.activities == 0
        ? l10n.weeklySnapshotEmpty
        : l10n.weeklySnapshotBody(
            snap.lessonsThisWeek,
            snap.starsEarned,
            snap.activeDays,
          );
    return Card(
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 28)),
        title: Text(
          nickname,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(summary),
        trailing: snap.activities == 0
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${snap.activities}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: WatotoColors.mango,
                    ),
                  ),
                  Text(
                    l10n.weeklyActivities,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
      ),
    );
  }
}

