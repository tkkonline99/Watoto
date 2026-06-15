import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'parent_gate.dart';

/// Authentication seam — Dart port of the design in `auth/` (auth.ts).
///
/// COPPA-aware: children never create credentialed accounts. The app runs an
/// ANONYMOUS session so a child can play offline immediately; when a PARENT
/// later signs up, that session is UPGRADED in place (progress preserved).
/// `getIdToken()` is what replaces the dev token on backend calls.
///
/// The default [LocalAuthService] keeps the app fully working offline with no
/// accounts and no network. A `FirebaseAuthService` drops in behind this same
/// interface once a Firebase project exists — see
/// `auth/FIREBASE_SETUP_FLUTTER.md` (the only thing that needs *your* project).
const consentPolicyVersion = '2026-06-01';

class AuthUser {
  const AuthUser({
    required this.uid,
    this.email,
    required this.isAnonymous,
    this.emailVerified = false,
  });

  final String uid;
  final String? email;
  final bool isAnonymous;
  final bool emailVerified;
}

abstract interface class AuthService {
  AuthUser? get current;

  /// Start (or resume) an anonymous session — safe to call on app launch.
  Future<AuthUser> ensureAnonymousSession();

  /// Create a parent account. Upgrades the anonymous session in place so the
  /// child's progress carries over. `consent` must be true (collected behind
  /// the parent gate) and is recorded with [consentPolicyVersion].
  Future<AuthUser> signUpParent({
    required String email,
    required String password,
    required bool consent,
    String? displayName,
  });

  Future<AuthUser> signInParent({required String email, required String password});

  Future<void> signOut();

  /// Token to send to the AWS backend (Authorization: Bearer …). Null in local
  /// mode; a Firebase ID token once Firebase is wired.
  Future<String?> getIdToken({bool forceRefresh = false});
}

/// Offline default: an in-memory anonymous session that can be upgraded to a
/// local parent record. No network, no real token — the app keeps using its
/// dev-token API path until Firebase is configured.
class LocalAuthService implements AuthService {
  static const _uuid = Uuid();

  AuthUser? _user;

  @override
  AuthUser? get current => _user;

  @override
  Future<AuthUser> ensureAnonymousSession() async =>
      _user ??= AuthUser(uid: _uuid.v4(), isAnonymous: true);

  @override
  Future<AuthUser> signUpParent({
    required String email,
    required String password,
    required bool consent,
    String? displayName,
  }) async {
    if (!consent) {
      throw StateError('Parental consent is required to create an account.');
    }
    final uid = _user?.uid.isNotEmpty == true ? _user!.uid : _uuid.v4();
    return _user = AuthUser(uid: uid, email: email, isAnonymous: false);
  }

  @override
  Future<AuthUser> signInParent({required String email, required String password}) async {
    final uid = _user?.uid.isNotEmpty == true ? _user!.uid : _uuid.v4();
    return _user = AuthUser(uid: uid, email: email, isAnonymous: false);
  }

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => null;
}

final authServiceProvider = Provider<AuthService>((_) => LocalAuthService());

/// One spelled-out parental-gate challenge per app session. Overridable in
/// tests so the answer is known.
final parentGateChallengeProvider =
    Provider<ParentGateChallenge>((_) => makeParentGate());
