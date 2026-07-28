/// Pure weekly progress maths for the parent dashboard.
library;

import '../../core/offline/offline_store.dart';

class WeeklySnapshot {
  const WeeklySnapshot({
    required this.lessonsThisWeek,
    required this.storiesThisWeek,
    required this.quizzesThisWeek,
    required this.starsEarned,
    required this.activeDays,
    required this.totalMinutes,
  });

  final int lessonsThisWeek;
  final int storiesThisWeek;
  final int quizzesThisWeek;
  final int starsEarned;
  final int activeDays;
  final int totalMinutes;

  int get activities => lessonsThisWeek + storiesThisWeek + quizzesThisWeek;
}

/// Monday 00:00 local of the week containing [now].
DateTime startOfWeek(DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  // DateTime.weekday: Mon=1 … Sun=7
  return day.subtract(Duration(days: day.weekday - 1));
}

bool _inWeek(DateTime? at, DateTime weekStart) {
  if (at == null) return false;
  final end = weekStart.add(const Duration(days: 7));
  return !at.isBefore(weekStart) && at.isBefore(end);
}

/// Build a weekly snapshot from stored progress timestamps.
WeeklySnapshot weeklySnapshotFor(
  OfflineStore store,
  String childId, {
  DateTime? now,
}) {
  final when = now ?? DateTime.now();
  final weekStart = startOfWeek(when);
  var lessons = 0;
  var stories = 0;
  var quizzes = 0;
  var stars = 0;
  var minutes = 0;
  final days = <String>{};

  for (final e in store.progressEntriesFor(childId)) {
    final at = e.at;
    if (!_inWeek(at, weekStart)) continue;
    days.add(
      '${at!.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}',
    );
    switch (e.kind) {
      case 'lesson':
        lessons++;
        minutes += (e.timeSpentS ?? 0) ~/ 60;
      case 'story':
        stories++;
      case 'quiz':
        quizzes++;
        stars += e.stars ?? 0;
        minutes += (e.timeSpentS ?? 0) ~/ 60;
    }
  }

  return WeeklySnapshot(
    lessonsThisWeek: lessons,
    storiesThisWeek: stories,
    quizzesThisWeek: quizzes,
    starsEarned: stars,
    activeDays: days.length,
    totalMinutes: minutes,
  );
}
