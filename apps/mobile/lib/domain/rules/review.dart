/// Pure spaced-review rules: what a child has actually learned, and when the
/// app should bring it back.
///
/// The engine used to be forward-only. Every resolver filtered on
/// `!hasCompletedLibraryItem`, so an activity finished at 30% was retired from
/// the app exactly as permanently as one finished at 100% — the child was
/// moved along and never met the material again. The adaptive nudge did not
/// close that hole: it shifted the *stage* and then picked a different, unseen
/// item, so the specific thing a child did not understand was the one thing
/// they were guaranteed not to see.
///
/// These rules are a small Leitner ladder. An attempt sorts an item into a
/// mastery band; the band moves the item along (or back down) a fixed ladder
/// of intervals; the item comes due again when that interval elapses. Nothing
/// here knows about Hive, providers, or widgets, so the scheduling decisions
/// can be tested exactly as they are made.
library;

/// How well a child did on one attempt at one activity.
enum MasteryLevel {
  /// Did not get it. Comes back tomorrow.
  shaky,

  /// Got it, with effort. Moves one rung up the ladder.
  firm,

  /// Clean and confident. Skips a rung.
  mastered,
}

/// Bands an attempt into a [MasteryLevel].
///
/// Retries matter as much as the final score: a child who reaches 100% on the
/// fifth try has not shown the same thing as one who reaches it on the first,
/// and the score alone cannot tell them apart. In this age band a retry is a
/// stronger signal of confusion than a few lost points, so it can pull an
/// otherwise-passing score down to [MasteryLevel.shaky].
MasteryLevel masteryFor({required int scorePct, int retries = 0}) {
  if (scorePct < 60 || retries >= 3) return MasteryLevel.shaky;
  if (scorePct >= 90 && retries <= 1) return MasteryLevel.mastered;
  return MasteryLevel.firm;
}

/// Days between reviews, by rung.
///
/// Four rungs spanning a month: soon enough that a shaky item is re-met while
/// the lesson is still recoverable, spaced enough that a child is not re-doing
/// the same activity every session. A child who clears the top rung has met
/// the material four times across ~31 days, which is where it stops being
/// worth their time — see [isRetired].
const reviewLadderDays = <int>[1, 3, 7, 21];

/// One activity's standing with one child.
///
/// [reps] is the ladder rung, not an attempt count: it moves down on a shaky
/// attempt and up on a good one, so it tracks *retention* rather than effort.
class ReviewRecord {
  const ReviewRecord({
    required this.itemId,
    required this.type,
    required this.subject,
    required this.stage,
    required this.lastScore,
    required this.retries,
    required this.reps,
    required this.lastAt,
    this.dueAt,
  });

  final String itemId;

  /// LibraryType name — 'lesson' | 'quiz' | 'story'.
  final String type;
  final String subject;
  final int stage;
  final int lastScore;
  final int retries;

  /// Rung on [reviewLadderDays]. At or past the end, the item is retired.
  final int reps;
  final DateTime lastAt;

  /// When this comes back, or null once it is retired.
  final DateTime? dueAt;

  MasteryLevel get mastery =>
      masteryFor(scorePct: lastScore, retries: retries);

  /// True once the child has held this across the whole ladder. Retired items
  /// are never served again — the app has run out of useful things to ask.
  bool get isRetired => dueAt == null;

  bool isDue(DateTime now) => dueAt != null && !dueAt!.isAfter(now);

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'type': type,
        'subject': subject,
        'stage': stage,
        'lastScore': lastScore,
        'retries': retries,
        'reps': reps,
        'lastAt': lastAt.toUtc().toIso8601String(),
        if (dueAt != null) 'dueAt': dueAt!.toUtc().toIso8601String(),
      };

  /// Returns null rather than throwing on a malformed row: a corrupt review
  /// entry should cost that one item's schedule, not the child's whole
  /// history.
  static ReviewRecord? fromJson(Map<String, dynamic> m) {
    final itemId = m['itemId'] as String?;
    final lastAt = DateTime.tryParse(m['lastAt'] as String? ?? '');
    if (itemId == null || itemId.isEmpty || lastAt == null) return null;
    final dueRaw = m['dueAt'] as String?;
    return ReviewRecord(
      itemId: itemId,
      type: m['type'] as String? ?? 'lesson',
      subject: m['subject'] as String? ?? '',
      stage: (m['stage'] as num?)?.toInt() ?? 1,
      lastScore: (m['lastScore'] as num?)?.toInt() ?? 0,
      retries: (m['retries'] as num?)?.toInt() ?? 0,
      reps: (m['reps'] as num?)?.toInt() ?? 0,
      lastAt: lastAt.toLocal(),
      dueAt: dueRaw == null ? null : DateTime.tryParse(dueRaw)?.toLocal(),
    );
  }
}

/// Where an attempt leaves an item on the ladder.
///
/// [previous] is null on a first attempt. The rung moves before the interval
/// is read, so the same attempt both decides the band and sets the next date:
///
/// * shaky — back to rung 0: tomorrow, however well it had been going before.
///   Forgetting is the signal the ladder exists to catch.
/// * firm — one rung up.
/// * mastered — two rungs up, so a child who plainly knows it is not made to
///   sit through every interval.
///
/// Past the top rung the item retires ([ReviewRecord.dueAt] null).
ReviewRecord scheduleAfterAttempt({
  required String itemId,
  required String type,
  required String subject,
  required int stage,
  required int scorePct,
  required int retries,
  required DateTime at,
  ReviewRecord? previous,
}) {
  final band = masteryFor(scorePct: scorePct, retries: retries);
  final from = previous?.reps ?? -1;
  final reps = switch (band) {
    MasteryLevel.shaky => 0,
    MasteryLevel.firm => from + 1,
    MasteryLevel.mastered => from + 2,
  };
  final rung = reps < 0 ? 0 : reps;
  final dueAt = rung >= reviewLadderDays.length
      ? null
      : at.add(Duration(days: reviewLadderDays[rung]));
  return ReviewRecord(
    itemId: itemId,
    type: type,
    subject: subject,
    stage: stage,
    lastScore: scorePct,
    retries: retries,
    reps: rung,
    lastAt: at,
    dueAt: dueAt,
  );
}

/// Items ready to come back, weakest first.
///
/// Ordering is deliberate: shaky material outranks firm regardless of how
/// overdue either is, because the point of the ladder is the thing the child
/// did not get. Ties break on the oldest due date so nothing can starve, and
/// finally on id so the list is stable across rebuilds — a "keep going" card
/// that reshuffles between frames is its own bug.
List<ReviewRecord> dueReviews(
  Iterable<ReviewRecord> records, {
  required DateTime now,
  int? limit,
}) {
  final due = records.where((r) => r.isDue(now)).toList()
    ..sort((a, b) {
      final byBand = a.mastery.index.compareTo(b.mastery.index);
      if (byBand != 0) return byBand;
      final byDue = a.dueAt!.compareTo(b.dueAt!);
      if (byDue != 0) return byDue;
      return a.itemId.compareTo(b.itemId);
    });
  if (limit == null || limit >= due.length) return due;
  return due.sublist(0, limit);
}

/// Everything still on the ladder that the child has not mastered, weakest
/// first — the parent-facing "needs practice" list.
///
/// Unlike [dueReviews] this ignores the due date. A parent asking what their
/// child is finding hard wants the honest answer now, not the subset the
/// scheduler happens to have queued for today.
List<ReviewRecord> needsPractice(
  Iterable<ReviewRecord> records, {
  int? limit,
}) {
  final weak = records
      .where((r) => !r.isRetired && r.mastery != MasteryLevel.mastered)
      .toList()
    ..sort((a, b) {
      final byBand = a.mastery.index.compareTo(b.mastery.index);
      if (byBand != 0) return byBand;
      final byScore = a.lastScore.compareTo(b.lastScore);
      if (byScore != 0) return byScore;
      return a.itemId.compareTo(b.itemId);
    });
  if (limit == null || limit >= weak.length) return weak;
  return weak.sublist(0, limit);
}
