import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_providers.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/watoto_theme.dart';
import '../../features/curriculum/age_picker.dart';
import '../../features/curriculum/subject_catalog.dart';
import '../../features/curriculum/subject_i18n.dart';
import '../../features/onboarding/savanna_background.dart';
import '../../l10n/gen/app_localizations.dart';

/// Child home — a welcome bar, the day's playable challenge, and a colourful
/// grid of the academic subjects + storybooks. There is no fixed stage: the
/// child picks an age when they open a subject or the daily challenge, then sees
/// content matched to that age. Styled to the savanna design (image 6); the
/// tiles are the app's real subjects so each one opens real content.
class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final child = ref.watch(activeChildProvider);
    final nickname = child?.nickname ?? '';
    final xp = ref.watch(xpProvider);

    return SavannaScaffold(
      topRight: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                streak: 0, // TODO: wire to a real streak when the store tracks one
                onProfiles: () => context.go('/profiles'),
                whoIsLearning: l10n.whoIsLearning,
              ),
              const SizedBox(height: 18),
              _DailyChallengeCard(l10n: l10n, xp: xp),
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
                      label: localizedSubject(subjectCatalog[i].englishLabel, lang),
                      onTap: () => _openSubjectForAge(
                        context,
                        subject: subjectCatalog[i],
                        heading:
                            localizedSubject(subjectCatalog[i].englishLabel, lang),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the age picker for [subject], then drills into that subject's content
/// for the chosen age. Shared by the activity tiles and the daily challenge.
Future<void> _openSubjectForAge(
  BuildContext context, {
  required SubjectCategory subject,
  required String heading,
}) async {
  final stage = await showAgePicker(
    context,
    stages: subject.stagesAvailable(),
    heading: heading,
  );
  if (stage == null || !context.mounted) return;
  final topic = subject.topicNameFor(stage)!;
  context.push('/subject/${stage.stage}/${Uri.encodeComponent(topic)}');
}

class _WelcomeBar extends StatelessWidget {
  const _WelcomeBar({
    required this.emoji,
    required this.greeting,
    required this.subtitle,
    required this.xp,
    required this.streak,
    required this.onProfiles,
    required this.whoIsLearning,
  });

  final String emoji;
  final String greeting;
  final String subtitle;
  final int xp;
  final int streak;
  final VoidCallback onProfiles;
  final String whoIsLearning;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message: whoIsLearning,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onProfiles,
            child: Container(
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
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: WatotoColors.deep,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: WatotoColors.deep.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatPill(emoji: '⭐', text: '$xp XP'),
        const SizedBox(width: 8),
        _StatPill(emoji: '🔥', text: '$streak'),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.emoji, required this.text});
  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

/// The hero "play now" card: the daily challenge with a gold play button and a
/// progress bar showing the child's XP toward the next 100.
class _DailyChallengeCard extends StatelessWidget {
  const _DailyChallengeCard({required this.l10n, required this.xp});

  final AppLocalizations l10n;
  final int xp;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _openSubjectForAge(
          context,
          subject: dailyChallengeSubject,
          heading: l10n.dailyChallenge,
        ),
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
                  color: WatotoColors.sun.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text('🦁', style: TextStyle(fontSize: 34)),
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
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: WatotoColors.deep,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (xp % 100) / 100,
                        minHeight: 10,
                        backgroundColor: WatotoColors.sun.withValues(alpha: 0.18),
                        valueColor:
                            const AlwaysStoppedAnimation(WatotoColors.sun),
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
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [WatotoColors.sun, WatotoColors.mango],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: WatotoColors.mango.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    size: 32, color: WatotoColors.deep),
              ),
            ],
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
  });

  final Color color;
  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
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
              Text(emoji, style: const TextStyle(fontSize: 30)),
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
    final loggedIn =
        ref.watch(sessionProvider.select((s) => s.parentAccessAllowed));
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
