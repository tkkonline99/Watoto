import 'dart:async';

import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics.dart';
import '../../core/audio/narration.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/widgets/mascot_widget.dart';
import '../../core/theme/watoto_theme.dart';
import '../../features/curriculum/age_picker.dart';
import '../../features/curriculum/curriculum_models.dart';
import '../../features/curriculum/subject_catalog.dart';
import '../../features/curriculum/subject_i18n.dart';
import '../../features/gamification/achievements_sheet.dart';
import '../../features/gamification/badge_toast.dart';
import '../../features/gamification/daily_challenge.dart';
import '../../features/gamification/mascot_mood.dart';
import '../../features/gamification/next_best.dart';
import '../../features/gamification/rewards.dart';
import '../../features/gamification/savanna_world.dart';
import '../../features/gamification/today_quest.dart';
import '../../features/gamification/word_of_the_day.dart';
import '../../features/library/library_repository.dart';
import '../../features/onboarding/guided_tour.dart';
import '../../features/onboarding/savanna_background.dart';
import '../../features/parent/family_layer.dart';
import '../../features/parent/reminders/reminder_service.dart';
import '../../features/profiles/child_profile.dart';
import '../../l10n/gen/app_localizations.dart';
import '../ai/ai_smart_practice_sheet.dart';
import '../ai/ai_story_weaver_sheet.dart';
import 'savanna_sketchpad_sheet.dart';

/// Child home — welcome bar, a concrete daily challenge, and subject tiles.
/// Age is inferred from the child's profile (and remembered after a long-press
/// change) so most taps go straight into content.
class ChildHomeScreen extends ConsumerStatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen> {
  // One bright colour per tile (5 subjects + storybooks fill the 3×2 grid).
  static const _tileColors = <Color>[
    Color(0xFF4DA6E5), // literacy — blue
    Color(0xFF4CB87B), // math — green
    Color(0xFFF4A62A), // science — orange
    Color(0xFF9D6FD8), // social — purple
    Color(0xFF2BB3A3), // tech — teal
  ];
  static const _storyColor = Color(0xFFEE6C5A); // coral

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushToastsAndTour();
      _refreshReminders();
    });
  }

  /// Re-queues practice reminders from current progress. A local notification
  /// cannot recompute its text when it fires, so the queue is rebuilt on every
  /// visit home — which is also every time an activity finishes. A family who
  /// played today therefore never receives the nudge queued for them.
  void _refreshReminders() {
    if (!mounted) return;
    if (!ref.read(offlineStoreProvider).remindersEnabled) return;
    unawaited(
      ref.read(reminderServiceProvider).refresh(
            l10n: AppLocalizations.of(context),
          ),
    );
  }

  void _flushToastsAndTour() {
    if (!mounted) return;
    final badges = ref.read(pendingBadgeToastProvider);
    if (badges.isNotEmpty) {
      final catalog = {for (final b in allBadges) b.id: b};
      showBadgeUnlockToast(
        context,
        newlyEarned: [
          for (final id in badges)
            if (catalog[id] != null) catalog[id]!,
        ],
      );
      // Spoken in the child's language. This used to read a hardcoded English
      // sentence aloud whatever the app was set to, and used the badge's
      // internal id ("threeLessons") as its name.
      final l10n = AppLocalizations.of(context);
      final lang = ref.read(localeProvider).languageCode;
      final first = badges.first;
      final label = badgeLabel(l10n, first);
      ref.read(narrationProvider.notifier).speak(
            '${l10n.badgeUnlocked} $label',
            lang,
            style: SpeakStyle.cheer,
          );
      ref.read(pendingBadgeToastProvider.notifier).state = [];
    }
    final level = ref.read(pendingLevelUpProvider);
    if (level > 0) {
      showLevelUpToast(context, level: level);
      final l10n = AppLocalizations.of(context);
      final lang = ref.read(localeProvider).languageCode;
      ref.read(narrationProvider.notifier).speak(
            l10n.levelUp(level),
            lang,
            style: SpeakStyle.cheer,
          );
      ref.read(pendingLevelUpProvider.notifier).state = 0;
    }
  }

  Future<void> _startGuidedTour() async {
    final child = ref.read(activeChildProvider);
    if (child == null) return;
    final lib = await ref.read(libraryProvider.future);
    final item = firstTourItem(child: child, library: lib);
    if (item == null) return;
    final lang = ref.read(localeProvider).languageCode;
    await ref.read(offlineStoreProvider).markTourPrompted(child.id);
    await ref.read(narrationProvider.notifier).speak(
          tourWelcomeSpeech(child.nickname, lang),
          lang,
          style: SpeakStyle.cheer,
        );
    if (!mounted) return;
    unawaited(context.push('/play/${item.id}'));
    await ref.read(offlineStoreProvider).markGuidedTourDone(child.id);
  }

  @override
  Widget build(BuildContext context) {
    // Re-flush toasts when providers update after a lesson.
    ref.listen(pendingBadgeToastProvider, (_, next) {
      if (next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _flushToastsAndTour());
      }
    });
    ref.listen(pendingLevelUpProvider, (_, next) {
      if (next > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _flushToastsAndTour());
      }
    });

    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final child = ref.watch(activeChildProvider);
    final nickname = child?.nickname ?? '';
    final xp = ref.watch(xpProvider);
    final streak = ref.watch(streakProvider);
    final coins = ref.watch(coinsProvider);
    final store = ref.watch(offlineStoreProvider);
    final showTour =
        child != null && store.needsGuidedTour(child.id);
    final subjectRings = _subjectRings(ref, child, store);

    // The savanna is the progress surface: everything the child has earned or
    // bought is drawn into the backdrop behind this screen.
    final world = child == null
        ? const <SceneDecoration>[]
        : [
            for (final d in visibleDecorations(
              purchased: store.unlockedDecorations(child.id),
              level: levelForXp(xp),
              subjectsExplored: store.completedSubjects(child.id).length,
            ))
              SceneDecoration(
                emoji: d.emoji,
                x: d.x,
                y: d.y,
                scale: d.scale,
              ),
          ];

    final bedtime = ref.watch(bedtimeModeProvider);
    final libRepo = ref.watch(libraryProvider).asData?.value;
    final memoryBoost = (child != null && libRepo != null)
        ? resolveMemoryBoostForChild(
            childId: child.id,
            store: store,
            library: libRepo,
          )
        : null;

    return SavannaScaffold(
      extras: world,
      bedtime: bedtime,
      topRight: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BedtimeToggleButton(bedtime: bedtime),
          const SizedBox(width: 8),
          _AccountButton(tooltip: l10n.account),
          const SizedBox(width: 8),
          _LanguageMenu(),
          const SizedBox(width: 8),
          SavannaLockButton(
            tooltip: l10n.parentZone,
            onTap: () => context.go('/parent'),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _WelcomeBar(
                emoji: child?.emoji ?? '🦁',
                greeting: l10n.homeGreeting(nickname),
                subtitle: l10n.homeSubtitle,
                xp: xp,
                streak: streak,
                coins: coins,
                level: levelForXp(xp),
                onProfiles: () => context.go('/profiles'),
                onAchievements: () => showAchievementsSheet(context, ref),
                onShop: () => context.push('/shop'),
                whoIsLearning: l10n.whoIsLearning,
                levelLabel: l10n.levelLabel(levelForXp(xp)),
              ),
              if (showTour) ...[
                const SizedBox(height: 14),
                _GuidedTourCard(
                  l10n: l10n,
                  nickname: nickname,
                  onStart: _startGuidedTour,
                  onSkip: () async {
                    await store.markGuidedTourDone(child.id);
                    setState(() {});
                  },
                ),
              ],
              const SizedBox(height: 14),
              _CheerBanner(l10n: l10n),
              _MascotCompanion(l10n: l10n),
              const _SavannaStickerBar(),
              const SizedBox(height: 14),
              // The challenge is the hero and stays above the fold: the quest
              // and "keep going" rows are ambient context, not the thing we
              // are asking the child to do.
              _DailyChallengeCard(l10n: l10n, xp: xp),
              const SizedBox(height: 12),
              _TodayQuestCard(l10n: l10n),
              const SizedBox(height: 12),
              _ContinueLearningCard(l10n: l10n),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.02,
                children: [
                  for (var i = 0; i < subjectCatalog.length; i++)
                    _ActivityTile(
                      color: _tileColors[i % _tileColors.length],
                      emoji: subjectCatalog[i].emoji,
                      progress: subjectRings[subjectCatalog[i].key],
                      label: localizedSubject(
                        subjectCatalog[i].englishLabel,
                        lang,
                      ),
                      semanticsHint: l10n.changeAgeHint,
                      onTap: () => _openSubject(
                        context,
                        ref,
                        subject: subjectCatalog[i],
                        heading: localizedSubject(
                          subjectCatalog[i].englishLabel,
                          lang,
                        ),
                        forceAgePicker: false,
                      ),
                      onLongPress: () => _openSubject(
                        context,
                        ref,
                        subject: subjectCatalog[i],
                        heading: localizedSubject(
                          subjectCatalog[i].englishLabel,
                          lang,
                        ),
                        forceAgePicker: true,
                      ),
                    ),
                  _ActivityTile(
                    color: _storyColor,
                    emoji: '📚',
                    label: l10n.storybooks,
                    onTap: () => context.go('/stories'),
                  ),
                ],
              ),
              if (memoryBoost != null && child != null) ...[
                const SizedBox(height: 14),
                KiboMemoryBoostCard(
                  recommendation: memoryBoost,
                  locale: lang,
                  onLaunch: () async {
                    await store.grantCoins(child.id, memoryBoost.bonusCoins);
                    ref.read(economyTickProvider.notifier).state++;
                    if (!context.mounted) return;
                    unawaited(context.push('/play/${memoryBoost.item.id}'));
                  },
                ),
              ],
              const SizedBox(height: 14),
              SavannaWordOfTheDayCard(locale: lang),
              const SizedBox(height: 12),
              _AiKidToolsRow(locale: lang),
            ],
          ),
        ),
      ),
    );
  }
}

/// Completion 0–1 per subject **at the child's current stage**, keyed by
/// [SubjectCategory.key], for the rings on the home tiles.
///
/// Returns an empty map until the library has loaded, or when there is no
/// active child — the tiles then simply render without a ring.
Map<String, double> _subjectRings(
  WidgetRef ref,
  ChildProfile? child,
  OfflineStore store,
) {
  ref.watch(xpProvider); // recompute after every completion
  final repo = ref.watch(libraryProvider).asData?.value;
  if (repo == null || child == null) return const {};

  final stage = stageForChild(child, store);
  final out = <String, double>{};
  for (final subject in subjectCatalog) {
    // The whole subject at this stage — every topic the tile holds, not just
    // the one a tap opens on.
    final items = [
      for (final topic in subject.topicNamesFor(stage))
        ...repo.forStageSubject(stage.stage, topic),
    ];
    if (items.isEmpty) continue;
    out[subject.key] = subjectProgress(
      store: store,
      childId: child.id,
      stage: stage.stage,
      subject: subject.englishLabel,
      items: [for (final i in items) (id: i.id, type: i.type.name)],
    );
  }
  return out;
}

/// A message a grown-up left. Kids repeat what adults notice, so this is the
/// highest-leverage social mechanic available at this age — and it needs no
/// leaderboard, no network and no free text.
///
/// Shown once: tapping it (or simply seeing it) clears the cheer, so it stays
/// news rather than becoming permanent wallpaper.
class _CheerBanner extends ConsumerStatefulWidget {
  const _CheerBanner({required this.l10n});
  final AppLocalizations l10n;

  @override
  ConsumerState<_CheerBanner> createState() => _CheerBannerState();
}

class _CheerBannerState extends ConsumerState<_CheerBanner> {
  PendingCheer? _cheer;

  @override
  void initState() {
    super.initState();
    final child = ref.read(activeChildProvider);
    if (child == null) return;
    final store = ref.read(offlineStoreProvider);
    final cheer = parseCheer(store.pendingCheer(child.id));
    // A cheer from a fortnight ago is not news; drop it silently.
    if (cheer == null || !cheer.isFreshAt(DateTime.now())) {
      if (cheer != null) unawaited(store.clearCheer(child.id));
      return;
    }
    _cheer = cheer;
    // Consume immediately: seen once is the whole point.
    unawaited(store.clearCheer(child.id));
  }

  @override
  Widget build(BuildContext context) {
    final cheer = _cheer;
    if (cheer == null) return const SizedBox.shrink();
    final l10n = widget.l10n;
    final text = switch (cheer.kind) {
      CheerKind.proud => l10n.cheerProud,
      CheerKind.wow => l10n.cheerWow,
      CheerKind.keepGoing => l10n.cheerKeepGoing,
      CheerKind.loveIt => l10n.cheerLoveIt,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        label: '${l10n.cheerFromGrownUp}. $text',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: WatotoColors.mango.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: WatotoColors.mango.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Text(
                  cheerEmoji(cheer.kind),
                  style: const TextStyle(fontSize: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.cheerFromGrownUp,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: WatotoColors.deep.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        text,
                        style: const TextStyle(
                          fontFamily: 'Baloo2',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: WatotoColors.deep,
                        ),
                      ),
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

/// The child's companion, with a name they chose and a mood that tracks how
/// the learning is actually going.
///
/// The mascot used to appear only on the celebration screen and vanish. A
/// companion that is *there*, remembers you, and visibly misses you is the
/// difference between a graphic and a relationship — and it is the cheapest
/// reason for a five-year-old to open the app tomorrow.
class _MascotCompanion extends ConsumerStatefulWidget {
  const _MascotCompanion({required this.l10n});
  final AppLocalizations l10n;

  @override
  ConsumerState<_MascotCompanion> createState() => _MascotCompanionState();
}

class _MascotCompanionState extends ConsumerState<_MascotCompanion> {
  int _tickleCount = 0;
  String? _tickledLine;

  void _tickle() {
    final lang = ref.read(localeProvider).languageCode;
    final line = mascotTickleSpeech(
      _tickleCount,
      lang,
      hour: DateTime.now().hour,
    );
    setState(() {
      _tickleCount++;
      _tickledLine = line;
    });
    unawaited(ref.read(soundEffectsProvider).star());
    unawaited(
      ref.read(narrationProvider.notifier).speak(
            line,
            lang,
            style: SpeakStyle.cheer,
          ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    String childId,
    String? current,
  ) async {
    final l10n = widget.l10n;
    final controller = TextEditingController(text: current ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.nameYourFriend),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: l10n.mascotNameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    await ref.read(offlineStoreProvider).setMascotName(childId, name);
    ref.read(economyTickProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final child = ref.watch(activeChildProvider);
    ref.watch(economyTickProvider); // name / streak changes
    if (child == null) return const SizedBox.shrink();

    final store = ref.watch(offlineStoreProvider);
    final streak = ref.watch(streakProvider);
    final name = store.mascotName(child.id);
    final baseMood = mascotMoodFor(
      lastActiveDayKey: store.lastActiveDayKey(child.id),
      streak: streak,
      now: DateTime.now(),
    );
    final mood = _tickleCount > 0 ? MascotMood.cheer : baseMood;

    final defaultLine = switch (baseMood) {
      MascotMood.sleep => l10n.mascotMissedYou,
      MascotMood.cheer => l10n.mascotProud(streak),
      MascotMood.think => l10n.mascotCurious,
      MascotMood.idle => l10n.mascotReady,
    };
    final line = _tickledLine ?? defaultLine;

    return Semantics(
      button: true,
      label: '${name ?? l10n.mascotDefaultName}. $line',
      child: Material(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _rename(context, ref, child.id, name),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    key: const ValueKey('mascot-tickle-target'),
                    onTap: _tickle,
                    child: AnimatedScale(
                      scale: _tickleCount.isOdd ? 1.14 : 1.0,
                      duration: const Duration(milliseconds: 160),
                      child: MascotWidget(mood: mood, size: 48),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name ?? l10n.mascotDefaultName,
                          style: const TextStyle(
                            fontFamily: 'Baloo2',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: WatotoColors.deep,
                          ),
                        ),
                        Text(
                          line,
                          key: const ValueKey('mascot-speech-line'),
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: WatotoColors.deep.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (name == null)
                    Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: WatotoColors.deep.withValues(alpha: 0.5),
                    ),
                  const SizedBox(width: 6),
                  IconButton(
                    key: const ValueKey('open-sketchpad-button'),
                    tooltip: 'Savanna Sketchpad',
                    onPressed: () => showSavannaSketchpad(context),
                    icon: const Icon(
                      Icons.palette_rounded,
                      color: WatotoColors.mango,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Interactive "My Savanna" sticker world strip on the child home screen.
///
/// Displays the animals and landmarks the child has earned or bought as
/// tappable stickers; tapping any sticker makes it bounce, sparkles, and
/// speaks a trilingual Savanna fun fact aloud.
class _SavannaStickerBar extends ConsumerStatefulWidget {
  const _SavannaStickerBar();

  @override
  ConsumerState<_SavannaStickerBar> createState() => _SavannaStickerBarState();
}

class _SavannaStickerBarState extends ConsumerState<_SavannaStickerBar> {
  String? _activeKey;
  String? _spokenFact;

  void _tapSticker(SavannaDecoration d) {
    final lang = ref.read(localeProvider).languageCode;
    final fact = savannaStickerGreeting(d.key, lang);
    setState(() {
      _activeKey = d.key;
      _spokenFact = fact;
    });
    unawaited(ref.read(soundEffectsProvider).star());
    unawaited(
      ref.read(narrationProvider.notifier).speak(
            fact,
            lang,
            style: SpeakStyle.cheer,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(activeChildProvider);
    ref.watch(economyTickProvider);
    final xp = ref.watch(xpProvider);
    final store = ref.watch(offlineStoreProvider);
    if (child == null) return const SizedBox.shrink();

    final unlocked = visibleDecorations(
      purchased: store.unlockedDecorations(child.id),
      level: levelForXp(xp),
      subjectsExplored: store.completedSubjects(child.id).length,
    );
    if (unlocked.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('savanna-sticker-bar'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final d in unlocked)
                    GestureDetector(
                      key: ValueKey('savanna-sticker-${d.key}'),
                      onTap: () => _tapSticker(d),
                      child: AnimatedScale(
                        scale: _activeKey == d.key ? 1.22 : 1.0,
                        duration: const Duration(milliseconds: 160),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _activeKey == d.key
                                ? WatotoColors.sun.withValues(alpha: 0.4)
                                : WatotoColors.leaf.withValues(alpha: 0.14),
                          ),
                          child: RichText(
                            text: TextSpan(
                              text: d.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (_spokenFact != null) ...[
                const SizedBox(height: 6),
                Text(
                  _spokenFact!,
                  key: const ValueKey('savanna-sticker-fact'),
                  style: const TextStyle(
                    fontFamily: 'Baloo2',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: WatotoColors.deep,
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

/// "Today's quest" — a gentle 3-activity daily goal. Deliberately not a timer
/// and not a comparison: the only thing it asks is that the child comes back.
class _TodayQuestCard extends ConsumerWidget {
  const _TodayQuestCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(activeChildProvider);
    ref.watch(xpProvider); // refresh as activities land
    if (child == null) return const SizedBox.shrink();

    final quest = todayQuestFor(ref.watch(offlineStoreProvider), child.id);
    final complete = quest.complete;
    final bedtime = ref.watch(bedtimeModeProvider);

    return Semantics(
      label: '${l10n.todayQuest}. '
          '${l10n.todayQuestProgress(quest.done, quest.goal)}',
      child: Material(
        color: bedtime
            ? Colors.white.withValues(alpha: 0.90)
            : (complete
                ? WatotoColors.leaf.withValues(alpha: 0.16)
                : WatotoColors.mango.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Text(
                  complete ? '🏅' : '🎯',
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complete ? l10n.todayQuestComplete : l10n.todayQuest,
                        style: const TextStyle(
                          fontFamily: 'Baloo2',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: WatotoColors.deep,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Pips rather than a bar: three discrete things to do
                      // reads as achievable to a child in a way a continuous
                      // bar does not.
                      Row(
                        children: [
                          for (var i = 0; i < quest.goal; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Container(
                                width: 26,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: i < quest.done
                                      ? (complete
                                          ? WatotoColors.leaf
                                          : WatotoColors.mango)
                                      : WatotoColors.deep
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  // Clamped: a busy afternoon can push the raw count past the
                  // goal, and "7/3" reads as a bug rather than as a win.
                  '${quest.done.clamp(0, quest.goal)}/${quest.goal}',
                  style: TextStyle(
                    fontFamily: 'Baloo2',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: WatotoColors.deep.withValues(alpha: 0.7),
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

class _GuidedTourCard extends StatelessWidget {
  const _GuidedTourCard({
    required this.l10n,
    required this.nickname,
    required this.onStart,
    required this.onSkip,
  });

  final AppLocalizations l10n;
  final String nickname;
  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WatotoColors.mango.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🦁', style: TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.tourTitle,
                    style: const TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: WatotoColors.deep,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tourBody(nickname.isEmpty ? 'friend' : nickname),
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),
            const SizedBox(height: 12),
            // Wrap, not Row: the labels are localized and the buttons carry a
            // child-sized minimum width, so on narrow phones (or at a large
            // text scale) "skip" drops to its own line instead of overflowing.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(
                  onPressed: onStart,
                  child: Text(l10n.tourStart),
                ),
                TextButton(onPressed: onSkip, child: Text(l10n.tourSkip)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens a subject at the child's preferred/profile stage (one tap). Long-press
/// forces the age picker so families can override for multi-age siblings.
Future<void> _openSubject(
  BuildContext context,
  WidgetRef ref, {
  required SubjectCategory subject,
  required String heading,
  required bool forceAgePicker,
}) async {
  final available = subject.stagesAvailable();
  if (available.isEmpty) return;

  final child = ref.read(activeChildProvider);
  final store = ref.read(offlineStoreProvider);
  CurriculumStage? stage;

  if (!forceAgePicker && child != null) {
    final preferred = stageForChild(child, store);
    for (final s in available) {
      if (s.stage == preferred.stage) {
        stage = s;
        break;
      }
    }
    stage ??= available.reduce(
      (a, b) => (a.stage - preferred.stage).abs() <=
              (b.stage - preferred.stage).abs()
          ? a
          : b,
    );
  }

  stage ??= await showAgePicker(
    context,
    stages: available,
    heading: heading,
  );
  if (stage == null || !context.mounted) return;

  if (child != null && forceAgePicker) {
    await store.setPreferredStage(child.id, stage.stage);
  }
  if (!context.mounted) return;

  final topic = subject.topicNameFor(stage);
  if (topic == null) return;
  unawaited(context.push('/subject/${stage.stage}/${Uri.encodeComponent(topic)}'));
}

class _WelcomeBar extends StatelessWidget {
  const _WelcomeBar({
    required this.emoji,
    required this.greeting,
    required this.subtitle,
    required this.xp,
    required this.streak,
    required this.coins,
    required this.level,
    required this.onProfiles,
    required this.onAchievements,
    required this.onShop,
    required this.whoIsLearning,
    required this.levelLabel,
  });

  final String emoji;
  final String greeting;
  final String subtitle;
  final int xp;
  final int streak;
  final int coins;
  final int level;
  final VoidCallback onProfiles;
  final VoidCallback onAchievements;
  final VoidCallback onShop;
  final String whoIsLearning;
  final String levelLabel;

  @override
  Widget build(BuildContext context) {
    final avatar = _ProfileAvatar(
      emoji: emoji,
      level: level,
      whoIsLearning: whoIsLearning,
      levelLabel: levelLabel,
      onTap: onProfiles,
    );
    final greetingBlock = _GreetingBlock(greeting: greeting, subtitle: subtitle);
    final stats = [
      _StatPill(
        emoji: '⭐',
        text: '$xp',
        semanticsLabel: '$xp XP · $levelLabel',
        onTap: onAchievements,
      ),
      _StatPill(
        emoji: '🔥',
        text: '$streak',
        semanticsLabel: AppLocalizations.of(context).streakLabel(streak),
        onTap: onAchievements,
      ),
      _StatPill(
        emoji: '🪙',
        text: '$coins',
        semanticsLabel: '$coins coins',
        onTap: onShop,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep the greeting readable when text is enlarged or the app is used
        // on a narrow phone. The old single row left only a sliver of room for
        // it after the three tappable stats.
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(child: greetingBlock),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: stats),
            ],
          );
        }
        return Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(child: greetingBlock),
            const SizedBox(width: 8),
            ..._separateWithSpacing(stats),
          ],
        );
      },
    );
  }
}

Iterable<Widget> _separateWithSpacing(List<Widget> children) sync* {
  for (var index = 0; index < children.length; index++) {
    if (index > 0) yield const SizedBox(width: 6);
    yield children[index];
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.emoji,
    required this.level,
    required this.whoIsLearning,
    required this.levelLabel,
    required this.onTap,
  });

  final String emoji;
  final int level;
  final String whoIsLearning;
  final String levelLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$whoIsLearning · $levelLabel',
      child: Tooltip(
        message: whoIsLearning,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: WatotoColors.sun, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: WatotoColors.deep.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ExcludeSemantics(
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: WatotoColors.mango,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      '$level',
                      style: const TextStyle(
                        fontFamily: 'Baloo2',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingBlock extends ConsumerWidget {
  const _GreetingBlock({required this.greeting, required this.subtitle});

  final String greeting;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bedtime = ref.watch(bedtimeModeProvider);
    final primary = bedtime ? const Color(0xFFFFF6E5) : WatotoColors.deep;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Baloo2',
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: primary,
          ),
        ),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: primary.withValues(alpha: bedtime ? 0.85 : 0.6),
          ),
        ),
      ],
    );
  }
}

/// "Keep going" row — the next activity chosen by the adaptive resolver.
///
/// This is where the attempt history the store has been collecting finally
/// does something: a child who has been struggling is offered an easier item,
/// one who is flying gets a harder one, and everyone else simply continues.
class _ContinueLearningCard extends ConsumerWidget {
  const _ContinueLearningCard({required this.l10n});
  final AppLocalizations l10n;

  /// Headline for why this activity was picked.
  ///
  /// Deliberately exhaustive with no default arm: adding a reason to
  /// [NextBestReason] should fail the build until someone decides what a child
  /// is told about it, rather than silently reading "Keep going".
  String _headline(NextBestReason reason) => switch (reason) {
        NextBestReason.adaptiveEasier => l10n.nextEasier,
        NextBestReason.adaptiveHarder => l10n.nextHarder,
        NextBestReason.discover => l10n.nextDiscover,
        // "Again", never "you got this wrong" — the ladder is invisible to the
        // child by design (docs/12 §12.6: no shame mechanics).
        NextBestReason.review => l10n.nextReview,
        // The daily challenge has its own card; continue/resume read the same
        // to a child, who only wants to know where the play button is.
        NextBestReason.dailyChallenge ||
        NextBestReason.continueNext ||
        NextBestReason.continueResume =>
          l10n.continueLearning,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(activeChildProvider);
    final libAsync = ref.watch(libraryProvider);
    ref.watch(xpProvider); // refresh after completions

    final target = libAsync.maybeWhen(
      data: (lib) {
        if (child == null) return null;
        return resolveNextBestForChild(
          child: child,
          store: ref.read(offlineStoreProvider),
          library: lib,
          // The Daily Challenge card below already offers that activity.
          skipDailyChallenge: true,
        );
      },
      orElse: () => null,
    );
    if (target == null) return const SizedBox.shrink();

    final headline = _headline(target.reason);
    final bedtime = ref.watch(bedtimeModeProvider);

    return Semantics(
      button: true,
      label: '$headline. ${target.item.title}',
      child: Material(
        color: bedtime
            ? Colors.white.withValues(alpha: 0.90)
            : WatotoColors.sky.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Which recommendation reason actually gets tapped is the signal
            // that tells us whether the adaptive engine is helping.
            ref.read(analyticsProvider).log(AnalyticsEvents.playNowTap, {
              'reason': target.reason.name,
              'stage': target.item.stage,
            });
            context.push('/play/${target.itemId}');
          },
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Text('▶️', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: const TextStyle(
                            fontFamily: 'Baloo2',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: WatotoColors.deep,
                          ),
                        ),
                        Text(
                          target.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: WatotoColors.deep.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: WatotoColors.deep,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.emoji,
    required this.text,
    required this.semanticsLabel,
    this.onTap,
  });
  final String emoji;
  final String text;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: WatotoColors.deep.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: WatotoColors.deep,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero card: a *specific* library activity for today, with done state + XP bar.
class _DailyChallengeCard extends ConsumerWidget {
  const _DailyChallengeCard({required this.l10n, required this.xp});

  final AppLocalizations l10n;
  final int xp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(activeChildProvider);
    final libAsync = ref.watch(libraryProvider);
    // Rebuild when XP changes so completion (bonus) refreshes the card.
    ref.watch(xpProvider);

    final challenge = libAsync.maybeWhen(
      data: (lib) {
        if (child == null) return null;
        final store = ref.read(offlineStoreProvider);
        // Pin once so bonus still awards after the activity is finished.
        final resolved = resolveDailyChallenge(
          child: child,
          store: store,
          library: lib,
        );
        if (resolved != null &&
            store.dailyChallengeTargetId(child.id) == null) {
          // Fire-and-forget pin; next rebuild sees the stable target.
          store.setDailyChallengeTarget(child.id, resolved.itemId);
        }
        return resolved;
      },
      orElse: () => null,
    );

    // Null until the library resolves a challenge — the card then shows just
    // its heading rather than repeating "Daily Challenge" as its own subtitle.
    final String? title = challenge == null
        ? null
        : (challenge.completed ? l10n.dailyChallengeDone : challenge.title);
    final emoji = challenge?.emoji ?? '🦁';
    final done = challenge?.completed ?? false;

    return Semantics(
      button: true,
      label: title == null ? l10n.dailyChallenge : '${l10n.dailyChallenge}. $title',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            if (challenge != null) {
              context.push('/play/${challenge.itemId}');
              return;
            }
            // Fallback: open today's subject at the child's stage.
            final subject = dailyChallengeSubjectFor(DateTime.now());
            _openSubject(
              context,
              ref,
              subject: subject,
              heading: l10n.dailyChallenge,
              forceAgePicker: false,
            );
          },
          // The label above already reads "Daily Challenge. <title>"; without
          // this the reader goes on to say the emoji, the title again and the
          // progress caption.
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: WatotoColors.deep.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: done
                          ? WatotoColors.leaf.withValues(alpha: 0.2)
                          : WatotoColors.sun.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 34)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.dailyChallenge,
                          style: const TextStyle(
                            fontFamily: 'Baloo2',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: WatotoColors.deep,
                          ),
                        ),
                        if (title != null)
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: WatotoColors.deep.withValues(alpha: 0.65),
                            ),
                          ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: done ? 1 : (xp % 100) / 100,
                            minHeight: 10,
                            backgroundColor: WatotoColors.sun.withValues(
                              alpha: 0.18,
                            ),
                            valueColor: AlwaysStoppedAnimation(
                              done ? WatotoColors.leaf : WatotoColors.sun,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: done
                            ? [WatotoColors.leaf, const Color(0xFF2E8B57)]
                            : const [WatotoColors.sun, WatotoColors.mango],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (done ? WatotoColors.leaf : WatotoColors.mango)
                              .withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      done ? Icons.check_rounded : Icons.play_arrow_rounded,
                      size: 32,
                      color: WatotoColors.deep,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.color,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.semanticsHint,
    this.progress,
  });

  final Color color;
  final String emoji;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticsHint;

  /// Completion 0–1 for this subject at the child's stage; null hides the ring
  /// (library still loading, or no content for this subject at this stage).
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final complete = p != null && p >= 1;
    // The label Text carries the accessible name; button:true gives it the
    // right role and the emoji is decorative (excluded) so it isn't read out.
    return Semantics(
      button: true,
      hint: semanticsHint,
      value: p == null ? null : '${(p * 100).round()}%',
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (p != null)
                          SizedBox.expand(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: p),
                              duration: const Duration(milliseconds: 650),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) =>
                                  CircularProgressIndicator(
                                value: value,
                                strokeWidth: 4,
                                strokeCap: StrokeCap.round,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.28),
                                valueColor: AlwaysStoppedAnimation(
                                  complete
                                      ? WatotoColors.sun
                                      : Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                            ),
                          ),
                        Text(emoji, style: const TextStyle(fontSize: 26)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Baloo2',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

/// Top-chrome button to the parent account screen (log in / create account).
/// A small green dot marks an active parent session.
class _AccountButton extends ConsumerWidget {
  const _AccountButton({required this.tooltip});
  final String tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(
      sessionProvider.select((s) => s.parentAccessAllowed),
    );
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.go('/account'),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: WatotoColors.deep.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.person_rounded, color: WatotoColors.deep),
              if (loggedIn)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: WatotoColors.leaf,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiKidToolsRow extends StatelessWidget {
  const _AiKidToolsRow({required this.locale});
  final String locale;

  @override
  Widget build(BuildContext context) {
    final storyLabel = switch (locale) {
      'sw' => '📖✨ Hadithi ya AI',
      'fr' => '📖✨ Histoire IA',
      _ => '📖✨ AI Story Weaver',
    };
    final practiceLabel = switch (locale) {
      'sw' => '🎯🤖 Mazoezi ya AI',
      'fr' => '🎯🤖 Pratique IA',
      _ => '🎯🤖 AI Smart Practice',
    };

    return ExcludeSemantics(
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('open-ai-story-weaver-button'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.88),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () => showAiStoryWeaver(context),
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  text: storyLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: WatotoColors.deep,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('open-ai-smart-practice-button'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.88),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () => showAiSmartPractice(context),
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  text: practiceLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: WatotoColors.deep,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BedtimeToggleButton extends ConsumerWidget {
  const _BedtimeToggleButton({required this.bedtime});
  final bool bedtime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExcludeSemantics(
      child: InkWell(
        key: const ValueKey('bedtime-mode-toggle'),
        customBorder: const CircleBorder(),
        onTap: () => ref.read(bedtimeModeProvider.notifier).toggle(),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bedtime ? const Color(0xFF28234A) : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: WatotoColors.deep.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            bedtime ? Icons.bedtime_rounded : Icons.wb_sunny_rounded,
            color: bedtime ? WatotoColors.sun : WatotoColors.mango,
          ),
        ),
      ),
    );
  }
}

class _LanguageMenu extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<Locale>(
      tooltip: l10n.chooseLanguage,
      onSelected: (locale) => ref.read(localeProvider.notifier).set(locale),
      itemBuilder: (context) => const [
        PopupMenuItem(value: Locale('en'), child: Text('English')),
        PopupMenuItem(value: Locale('sw'), child: Text('Kiswahili')),
        PopupMenuItem(value: Locale('fr'), child: Text('Français')),
      ],
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: WatotoColors.deep.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.language_rounded, color: WatotoColors.deep),
      ),
    );
  }
}
