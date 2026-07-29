/// "What's new" release notes for grown-ups (parent zone).
///
/// Keep entries short, kid-friendly product language, and newest first.
/// [appVersion] should match the marketing version in pubspec (`1.0.0`).
library;

/// One shipped release note block.
class WhatsNewRelease {
  const WhatsNewRelease({
    required this.version,
    required this.title,
    required this.bullets,
  });

  final String version;
  final String title;
  final List<String> bullets;
}

/// Marketing version string (no build number).
const String appWhatsNewVersion = '1.0.0';

/// Newest first. Update when shipping a store build.
const List<WhatsNewRelease> whatsNewReleases = [
  WhatsNewRelease(
    version: '1.0.0',
    title: 'Free offline launch',
    bullets: [
      'Full offline library — stages 1–10 free in this build (no purchases)',
      'Play now hero, daily challenge, combos, and Keep going celebrations',
      'First-of-day high five for grown-ups + kids',
      'Toddler co-play tips and bigger buttons on stages 1–2',
      'Hero art across all 10 stages + full VO packs (EN/FR/SW)',
      'Home themes and avatars (coins = looks only, never lessons)',
      'Stretch break after longer play, streak shield once a week',
      'Friendly empty/error screens, larger text support, screen-reader labels',
      'Parent zone: weekly snapshot, copy progress, guides, screen time',
    ],
  ),
  WhatsNewRelease(
    version: '0.9.0',
    title: 'Preview foundations',
    bullets: [
      'Lessons, quizzes, and stories with offline progress',
      'English, French, and Swahili text + read-aloud',
      'Parent PIN gate and multi-child profiles',
    ],
  ),
];
