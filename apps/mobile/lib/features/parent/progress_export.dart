/// Pure parent progress export — clipboard / share-friendly plain text.
///
/// No PII beyond nickname and learning stats already stored on device.
library;

import '../../core/offline/offline_store.dart';
import '../gamification/badge_stats_source.dart';
import '../gamification/rewards.dart';
import '../profiles/child_profile.dart';
import 'weekly_snapshot.dart';

/// Build a multi-child weekly report for grown-ups (email, notes, teacher).
String buildProgressExportReport({
  required OfflineStore store,
  required List<ChildProfile> children,
  DateTime? now,
  String appName = 'Watoto',
}) {
  final when = now ?? DateTime.now();
  final weekStart = startOfWeek(when);
  final weekEnd = weekStart.add(const Duration(days: 6));
  final buf = StringBuffer()
    ..writeln('$appName — learning progress')
    ..writeln('${_fmtDate(weekStart)} → ${_fmtDate(weekEnd)}')
    ..writeln('Generated ${_fmtDate(when)}')
    ..writeln('');

  if (children.isEmpty) {
    buf.writeln('No child profiles yet.');
    return buf.toString();
  }

  for (final child in children) {
    buf.write(_childSection(store, child, when));
    buf.writeln('');
  }

  buf
    ..writeln('—')
    ..writeln(
      'Shared from $appName (offline). No ads. Progress stays on this device.',
    );
  return buf.toString();
}

/// One-child report (same stats as the family export, focused header).
String buildSingleChildProgressExport({
  required OfflineStore store,
  required ChildProfile child,
  DateTime? now,
  String appName = 'Watoto',
}) {
  final when = now ?? DateTime.now();
  final weekStart = startOfWeek(when);
  final weekEnd = weekStart.add(const Duration(days: 6));
  final buf = StringBuffer()
    ..writeln('$appName — ${child.nickname}\'s progress')
    ..writeln('${_fmtDate(weekStart)} → ${_fmtDate(weekEnd)}')
    ..writeln('Generated ${_fmtDate(when)}')
    ..writeln('')
    ..write(_childSection(store, child, when))
    ..writeln('')
    ..writeln('—')
    ..writeln(
      'Shared from $appName (offline). No ads. Progress stays on this device.',
    );
  return buf.toString();
}

String _childSection(OfflineStore store, ChildProfile child, DateTime when) {
  final snap = weeklySnapshotFor(store, child.id, now: when);
  final xp = store.xpFor(child.id);
  final level = levelForXp(xp);
  final streak = store.streakFor(child.id);
  final stars = store.totalStars(child.id);
  final lessons = store.completedLessonCount(child.id);
  final stories = store.completedStoryCount(child.id);
  final quizzes = store.completedQuizCount(child.id);
  final badges = earnedBadges(badgeStatsFor(store, child.id));

  final buf = StringBuffer()
    ..writeln('—— ${child.nickname} ${child.emoji} ——')
    ..writeln('Level $level · $xp XP · streak $streak days · $stars stars')
    ..writeln(
      'Week: ${snap.lessonsThisWeek} lessons, '
      '${snap.quizzesThisWeek} quizzes, '
      '${snap.storiesThisWeek} stories · '
      '${snap.activeDays} active days · '
      '~${snap.totalMinutes} min',
    )
    ..writeln(
      'All time: $lessons lessons, $quizzes quizzes, $stories stories',
    );
  if (badges.isNotEmpty) {
    buf.writeln(
      'Badges: ${badges.map((b) => '${b.emoji} ${b.id}').join(', ')}',
    );
  } else {
    buf.writeln('Badges: (none yet)');
  }
  return buf.toString();
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
