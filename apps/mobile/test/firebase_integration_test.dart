import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';
import 'package:watoto_mobile/core/offline/sync_op.dart';
import 'package:watoto_mobile/data/cloud/cloud_sync.dart';
import 'package:watoto_mobile/features/auth/auth_service.dart';
import 'package:watoto_mobile/features/auth/entitlements.dart';
import 'package:watoto_mobile/features/auth/firebase_auth_service.dart';
import 'package:watoto_mobile/features/auth/iap_bridge.dart';
import 'package:watoto_mobile/features/onboarding/consent.dart';
import 'package:watoto_mobile/firebase/firebase_bootstrap.dart';
import 'package:watoto_mobile/firebase_options.dart';

class _FakeFirebaseAuthBackend implements FirebaseAuthBackend {
  AuthUser? user;
  final Map<String, Map<String, Object?>> accountDocs = {};
  final List<Map<String, Object?>> consents = [];
  final List<String> resetEmails = [];
  bool deletionRequested = false;

  @override
  AuthUser? get currentUser => user;

  @override
  Future<AuthUser> signInAnonymously() async {
    return user ??= const AuthUser(uid: 'anon-uid-1', isAnonymous: true);
  }

  @override
  Future<AuthUser> createOrLinkParent({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final uid = user?.uid ?? 'parent-uid-1';
    return user = AuthUser(uid: uid, email: email, isAnonymous: false);
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return user = AuthUser(uid: 'signed-in-uid', email: email, isAnonymous: false);
  }

  @override
  Future<void> signOut() async {
    user = null;
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      user == null ? null : 'id-token-for-${user!.uid}';

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetEmails.add(email);
  }

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {}

  @override
  Future<void> upsertAccountDoc({
    required String uid,
    required Map<String, Object?> data,
  }) async {
    accountDocs[uid] = Map<String, Object?>.from(data);
  }

  @override
  Future<void> recordConsent({
    required String uid,
    required String policyVersion,
    required String method,
  }) async {
    consents.add({
      'uid': uid,
      'policyVersion': policyVersion,
      'method': method,
    });
  }

  @override
  Future<void> requestAccountDeletion() async {
    deletionRequested = true;
  }

  @override
  Future<Map<String, dynamic>> exportAccountData() async {
    return {'accounts': accountDocs, 'consents': consents};
  }
}

class _FakeFirestoreSyncWriter implements FirestoreSyncWriter {
  final Map<String, Map<String, Object?>> profiles = {};
  final Map<String, Map<String, Object?>> progress = {};

  @override
  Future<void> setProfile({
    required String uid,
    required String profileId,
    required Map<String, Object?> data,
  }) async {
    profiles['$uid/$profileId'] = data;
  }

  @override
  Future<void> setProgress({
    required String uid,
    required String profileId,
    required String itemId,
    required Map<String, Object?> data,
  }) async {
    progress['$uid/$profileId/$itemId'] = data;
  }
}

void main() {
  tearDown(() {
    debugSetFirebaseInitialized(false);
  });

  group('Firebase bootstrap & offline fallback', () {
    test('DefaultFirebaseOptions is unconfigured by default and falls back cleanly', () async {
      expect(DefaultFirebaseOptions.isConfigured, isFalse);
      final initialized = await initializeWatotoFirebase();
      expect(initialized, isFalse);
      expect(isFirebaseInitialized, isFalse);
      expect(createAuthService(), isA<LocalAuthService>());
    });

    test('createAuthService returns FirebaseAuthService when Firebase is initialized', () {
      debugSetFirebaseInitialized(true);
      expect(createAuthService(), isA<FirebaseAuthService>());
    });
  });

  group('FirebaseAuthService & Firestore security rule invariants', () {
    test('signUpParent upgrades anonymous session, omits server fields, and records consent', () async {
      debugSetFirebaseInitialized(true);
      final backend = _FakeFirebaseAuthBackend();
      final auth = FirebaseAuthService(backend: backend);

      final anon = await auth.ensureAnonymousSession();
      expect(anon.isAnonymous, isTrue);
      expect(anon.uid, 'anon-uid-1');

      await expectLater(
        auth.signUpParent(
          email: 'parent@example.com',
          password: 'secretPassword123',
          consent: false,
        ),
        throwsStateError,
      );

      final upgraded = await auth.signUpParent(
        email: '  parent@example.com ',
        password: 'secretPassword123',
        consent: true,
        displayName: 'Mama Amina',
      );
      expect(upgraded.uid, 'anon-uid-1'); // same uid preserved!
      expect(upgraded.isAnonymous, isFalse);
      expect(upgraded.email, 'parent@example.com');

      final accountDoc = backend.accountDocs['anon-uid-1']!;
      expect(accountDoc['email'], 'parent@example.com');
      expect(accountDoc['displayName'], 'Mama Amina');
      expect(accountDoc['consentVersion'], consentPolicyVersion);
      // firestore.rules: client create/update must NEVER touch plan, entitlementExpiry, deletedAt.
      expect(accountDoc.containsKey('plan'), isFalse);
      expect(accountDoc.containsKey('entitlementExpiry'), isFalse);
      expect(accountDoc.containsKey('deletedAt'), isFalse);

      expect(backend.consents, hasLength(1));
      expect(backend.consents.single['method'], 'signup-checkbox');
      expect(backend.consents.single['policyVersion'], consentPolicyVersion);

      await auth.requestAccountDeletion();
      expect(backend.deletionRequested, isTrue);
    });
  });

  group('FirestoreSyncApi & COPPA profile/progress schema', () {
    test('syncs child profiles without PII and writes progress with Timestamp updatedAt', () async {
      final store = await OfflineStore.open(inMemory: true);
      final child = await store.completeOnboarding(
        consent: ConsentRecord(
          coreData: true,
          aiFeatures: false,
          voiceRecording: false,
          recordedAt: DateTime.utc(2026, 1, 1),
        ),
        pin: '1234',
        nickname: 'Amina',
        avatarKey: 'lion',
        birthYear: DateTime.now().year - 4,
      );
      await store.recordLessonCompleted(
        childId: child.id,
        lessonId: 's01.cause.lesson.01',
        scorePct: 100,
        timeSpentS: 45,
        xpEarned: 25,
      );

      final writer = _FakeFirestoreSyncWriter();
      final syncApi = FirestoreSyncApi(
        uidProvider: () => 'parent-uid-42',
        store: store,
        writer: writer,
      );

      final pending = store.pendingOps;
      expect(pending, hasLength(1));
      final res = await syncApi.syncBatch(pending);
      expect(res, {pending.single.clientOpId: 'applied'});

      final profileDoc = writer.profiles['parent-uid-42/${child.id}']!;
      expect(profileDoc['displayName'], 'Amina');
      expect(profileDoc['ageBand'], '3-5');
      expect(profileDoc['updatedAt'], isA<Timestamp>());
      for (final pii in FirestoreSyncApi.forbiddenProfilePiiKeys) {
        expect(profileDoc.containsKey(pii), isFalse, reason: 'Forbidden PII key: $pii');
      }

      final progressDoc =
          writer.progress['parent-uid-42/${child.id}/s01.cause.lesson.01']!;
      expect(progressDoc['opType'], 'lesson_progress');
      expect(progressDoc['scorePct'], 100);
      expect(progressDoc['updatedAt'], isA<Timestamp>());
    });

    test('keeps ops queued when no user session is active', () async {
      final writer = _FakeFirestoreSyncWriter();
      final syncApi = FirestoreSyncApi(
        uidProvider: () => null,
        writer: writer,
      );
      final op = SyncOp(
        clientOpId: 'op-1',
        opType: 'story_read',
        payload: {'childId': 'c1', 'storyId': 's01.cause.story.01'},
        clientUpdatedAt: DateTime.utc(2026, 5, 1),
      );
      final res = await syncApi.syncBatch([op]);
      expect(res, isEmpty);
      expect(writer.progress, isEmpty);
    });
  });

  group('Cloud Functions receipt verification & Firestore entitlement sync', () {
    test('verifyStoreReceiptCallable normalizes ios/android to apple/google and parses expiry', () async {
      Map<String, Object?>? captured;
      final expMs = DateTime.now().toUtc().add(const Duration(days: 30)).millisecondsSinceEpoch;
      final res = await verifyStoreReceiptCallable(
        platform: 'ios',
        productId: premiumMonthlyId,
        receipt: 'tx-12345',
        accountToken: 'uid-99',
        caller: (payload) async {
          captured = payload;
          return {
            'ok': true,
            'plan': 'premium',
            'entitlementExpiry': expMs,
          };
        },
      );
      expect(captured?['platform'], 'apple');
      expect(res.valid, isTrue);
      expect(res.expiry?.millisecondsSinceEpoch, expMs);
    });

    test('EntitlementService.refreshFromServer syncs Firestore account plan into local store', () async {
      final store = await OfflineStore.open(inMemory: true);
      final svc = EntitlementService(store);
      expect(svc.current.isPremium, isFalse);

      final futureExpiry = DateTime.now().toUtc().add(const Duration(days: 60));
      final updated = await svc.refreshFromServer(
        'uid-99',
        fetcher: (uid) => fetchServerEntitlement(
          uid,
          docReader: (_) async => {
            'plan': 'premium',
            'entitlementExpiry': Timestamp.fromDate(futureExpiry),
          },
        ),
      );
      expect(updated.isPremium, isTrue);
      expect(updated.plan, 'premium');
    });
  });
}
