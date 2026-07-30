/// What the app infers from a child's history: where to go next, whether to
/// make it easier or harder, and what is due back on the review ladder.
part of 'offline_store.dart';

extension OfflineStoreInsights on OfflineStore {
  // --------------------------------------------------------------- continue

  /// Last library item the child opened/finished: {itemId, stage, subject}.
  Map<String, dynamic>? lastPlayed(String childId) {
    final raw = _account.get('lastPlayed:$childId');
    if (raw == null) return null;
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  Future<void> setLastPlayed({
    required String childId,
    required String itemId,
    required int stage,
    required String subject,
  }) =>
      _account.put(
        'lastPlayed:$childId',
        jsonEncode({
          'itemId': itemId,
          'stage': stage,
          'subject': subject,
        }),
      );

  // --------------------------------------------------------------- adaptive

  /// Append a graded attempt for adaptive difficulty (capped list in JSON).
  ///
  /// Pass [itemId] (with [type], [subject], [stage]) whenever the caller knows
  /// what was attempted — it is what puts the item on the review ladder. The
  /// arguments are optional only because the anonymous form predates the
  /// ladder and older stored attempts have no id to recover; every call site
  /// in the app supplies them.
  Future<void> recordAttemptOutcome({
    required String childId,
    required int scorePct,
    required int retries,
    String? itemId,
    String type = 'lesson',
    String subject = '',
    int stage = 1,
    DateTime? at,
  }) async {
    if (itemId != null && itemId.isNotEmpty) {
      await _recordReview(
        childId: childId,
        itemId: itemId,
        type: type,
        subject: subject,
        stage: stage,
        scorePct: scorePct,
        retries: retries,
        at: at ?? DateTime.now(),
      );
    }
    final key = 'attempts:$childId';
    final raw = _account.get(key);
    final list = <Map<String, dynamic>>[];
    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final e in decoded) {
          if (e is Map) list.add(e.cast<String, dynamic>());
        }
      }
    }
    list.add({
      'scorePct': scorePct,
      'retries': retries,
      'at': (at ?? DateTime.now()).toUtc().toIso8601String(),
      if (itemId != null && itemId.isNotEmpty) 'itemId': itemId,
    });
    while (list.length > 20) {
      list.removeAt(0);
    }
    await _account.put(key, jsonEncode(list));
  }

  List<({int scorePct, int retries, DateTime at})> attemptHistory(
    String childId,
  ) {
    final raw = _account.get('attempts:$childId');
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <({int scorePct, int retries, DateTime at})>[];
    for (final e in decoded) {
      if (e is! Map) continue;
      final m = e.cast<String, dynamic>();
      final at = DateTime.tryParse(m['at'] as String? ?? '');
      if (at == null) continue;
      out.add((
        scorePct: (m['scorePct'] as num?)?.toInt() ?? 0,
        retries: (m['retries'] as num?)?.toInt() ?? 0,
        at: at,
      ));
    }
    return out;
  }

  /// Adaptive history as [AttemptOutcome]-compatible records (score/retries/at).
  List<({int scorePct, int retries, DateTime at})> recentAttemptOutcomes(
    String childId,
  ) =>
      attemptHistory(childId);

  // ----------------------------------------------------------- review ladder

  /// Every activity this child has attempted, with its place on the review
  /// ladder. Keyed by item id, so unlike `attempts:` it is not capped — the
  /// schedule has to outlive the last twenty attempts to be worth anything.
  List<ReviewRecord> reviewRecords(String childId) {
    final raw = _account.get('review:$childId');
    if (raw == null || raw.isEmpty) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! Map) return const [];
    final out = <ReviewRecord>[];
    for (final entry in decoded.values) {
      if (entry is! Map) continue;
      final rec = ReviewRecord.fromJson(entry.cast<String, dynamic>());
      if (rec != null) out.add(rec);
    }
    return out;
  }

  ReviewRecord? reviewRecordFor(String childId, String itemId) {
    for (final r in reviewRecords(childId)) {
      if (r.itemId == itemId) return r;
    }
    return null;
  }

  /// Activities due to come back, weakest first.
  List<ReviewRecord> dueReviewsFor(String childId, {DateTime? now, int? limit}) =>
      dueReviews(
        reviewRecords(childId),
        now: now ?? DateTime.now(),
        limit: limit,
      );

  /// Unmastered activities regardless of due date — the parent-facing list.
  List<ReviewRecord> needsPracticeFor(String childId, {int? limit}) =>
      needsPractice(reviewRecords(childId), limit: limit);

  /// Moves one item along the ladder after a graded attempt.
  Future<void> _recordReview({
    required String childId,
    required String itemId,
    required String type,
    required String subject,
    required int stage,
    required int scorePct,
    required int retries,
    required DateTime at,
  }) async {
    final next = scheduleAfterAttempt(
      itemId: itemId,
      type: type,
      subject: subject,
      stage: stage,
      scorePct: scorePct,
      retries: retries,
      at: at,
      previous: reviewRecordFor(childId, itemId),
    );
    final map = <String, dynamic>{
      for (final r in reviewRecords(childId)) r.itemId: r.toJson(),
    };
    map[itemId] = next.toJson();
    await _account.put('review:$childId', jsonEncode(map));
  }
}
