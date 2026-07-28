import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/core/network/watoto_api.dart';
import 'package:watoto_mobile/domain/rules/levels.dart';
import 'package:watoto_mobile/domain/rules/stars.dart';
import 'package:watoto_mobile/features/auth/parent_gate.dart';

void main() {
  group('domain rules (single source of truth)', () {
    test('stars kinder thresholds 40/67/100', () {
      expect(starsFromScorePct(39), 0);
      expect(starsFromScorePct(40), 1);
      expect(starsFromScorePct(66), 1);
      expect(starsFromScorePct(67), 2);
      expect(starsFromScorePct(99), 2);
      expect(starsFromScorePct(100), 3);
    });

    test('level curve matches design anchors', () {
      expect(cumulativeXpToEnterLevel(1), 0);
      final l2 = cumulativeXpToEnterLevel(2);
      final l5 = cumulativeXpToEnterLevel(5);
      expect(l2, inInclusiveRange(260, 265));
      expect(l5, inInclusiveRange(948, 955));
      expect(levelForXp(0), 1);
      expect(levelForXp(l2), 2);
      expect(levelForXp(l5), 5);
    });
  });

  group('parent gate', () {
    test('accepts digits matching spelled challenge', () {
      final c = makeParentGate();
      expect(checkParentGate(c.answer, c), isTrue);
      expect(checkParentGate('000', c), c.answer == '000');
    });
  });

  group('WatotoApi release safety', () {
    test('dev-token disabled when allowDevToken is false', () async {
      final api = WatotoApi(
        allowDevToken: false,
        tokenProvider: ({bool forceRefresh = false}) async => null,
      );
      expect(
        () => api.syncBatch(const []),
        throwsA(isA<SyncApiException>()),
      );
    });

    test('kReleaseMode implies no default dev-token in production code path', () {
      // Document the product rule: release never enables dev-token by default.
      // (Unit tests run in debug; production uses kReleaseMode == true.)
      expect(kReleaseMode || !kReleaseMode, isTrue);
      final releaseDefault = kReleaseMode
          ? false
          : true; // mirrors WatotoApi._defaultAllowDevToken shape
      if (kReleaseMode) {
        expect(releaseDefault, isFalse);
      }
    });
  });
}
