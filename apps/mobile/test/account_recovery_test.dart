import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/features/auth/auth_service.dart';

void main() {
  group('username cooldown', () {
    test('allows first change and blocks within 90 days', () {
      expect(canChangeNickname(null), isTrue);
      final last = DateTime.utc(2026, 1, 1);
      expect(
        canChangeNickname(last, now: DateTime.utc(2026, 2, 1)),
        isFalse,
      );
      expect(
        canChangeNickname(last, now: DateTime.utc(2026, 4, 2)),
        isTrue,
      );
      expect(
        nicknameCooldownDaysRemaining(last, now: DateTime.utc(2026, 1, 15)),
        greaterThan(0),
      );
    });
  });

  group('password + pin recovery (local store)', () {
    late OfflineStore store;
    late Directory dir;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('watoto_recovery_');
      Hive.init(dir.path);
      store = await OfflineStore.open();
    });

    tearDown(() async {
      await store.close();
      await Hive.deleteFromDisk();
    });

    test('password reset code flow updates password', () async {
      await store.createAccount('parent@example.com', 'oldpass1');
      final auth = LocalAuthService(store: store);
      final req = await auth.requestLocalPasswordReset('parent@example.com');
      expect(req.localResetCode, isNotNull);
      expect(req.localResetCode!.length, 6);

      await auth.confirmPasswordReset(
        code: req.localResetCode!,
        newPassword: 'newpass9',
      );
      expect(await store.signIn('parent@example.com', 'newpass9'), isTrue);
      expect(await store.signIn('parent@example.com', 'oldpass1'), isFalse);
    });

    test('unknown email cannot begin reset', () async {
      await store.createAccount('parent@example.com', 'secret12');
      expect(
        () => store.beginPasswordReset('other@example.com'),
        throwsStateError,
      );
    });

    test('pin reset with password', () async {
      await store.createAccount('parent@example.com', 'secret12');
      await store.setPin('1234');
      await store.resetPinWithPassword(password: 'secret12', newPin: '5678');
      expect(store.verifyPin('5678'), isTrue);
      expect(store.verifyPin('1234'), isFalse);
    });

    test('nickname 90-day policy on store', () async {
      final child = await store.addChild(
        nickname: 'Amani',
        avatarKey: 'lion',
        birthYear: 2019,
      );
      // Initial nickname can be fixed once (no prior change timestamp).
      expect(store.canEditChildNickname(child.id), isTrue);
      final updated = await store.updateChildNickname(
        childId: child.id,
        nickname: 'Zuri',
      );
      expect(updated.nickname, 'Zuri');
      // Next change blocked for 90 days.
      expect(store.canEditChildNickname(child.id), isFalse);
      final aged = updated.copyWith(
        nicknameChangedAt:
            DateTime.now().toUtc().subtract(const Duration(days: 91)),
      );
      await store.updateChild(aged);
      expect(store.canEditChildNickname(child.id), isTrue);
    });
  });
}
