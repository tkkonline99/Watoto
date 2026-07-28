import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/offline/offline_store.dart';
import '../../domain/ports/auth_port.dart';
import 'parent_gate.dart';

export '../../domain/models/consent.dart' show consentPolicyVersion;
export '../../domain/ports/auth_port.dart' show AuthPort, AuthUser;

/// Authentication seam — implements [AuthPort] (domain).
///
/// COPPA-aware: children never create credentialed accounts. The app runs an
/// ANONYMOUS session so a child can play offline immediately; when a PARENT
/// later signs up, that session is UPGRADED in place (progress preserved).
///
/// [LocalAuthService] is the offline default. Firebase drops in behind the
/// same interface once a project exists (see firebase_auth_service.dart).
typedef AuthService = AuthPort;

/// Result of requesting a password reset (for UI messaging).
class PasswordResetRequestResult {
  const PasswordResetRequestResult({
    required this.email,
    this.localResetCode,
    this.mailtoUri,
  });

  final String email;

  /// Only populated in offline mode so the device owner can complete reset
  /// if the mail client did not open. Never log this in production analytics.
  final String? localResetCode;

  /// Optional `mailto:` URI the UI can launch.
  final Uri? mailtoUri;
}

/// Offline default: in-memory anonymous session + local password reset via
/// one-time codes emailed with a mailto: handoff (and OfflineStore).
class LocalAuthService implements AuthService {
  LocalAuthService({OfflineStore? store}) : _store = store;

  static const _uuid = Uuid();

  AuthUser? _user;
  OfflineStore? _store;

  /// Bound after bootstrap when the Hive store is open.
  void bindStore(OfflineStore store) => _store = store;

  OfflineStore get _requireStore {
    final s = _store;
    if (s == null) {
      throw StateError('LocalAuthService has no OfflineStore bound.');
    }
    return s;
  }

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
  Future<AuthUser> signInParent({
    required String email,
    required String password,
  }) async {
    final uid = _user?.uid.isNotEmpty == true ? _user!.uid : _uuid.v4();
    return _user = AuthUser(uid: uid, email: email, isAnonymous: false);
  }

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => null;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    // Prefer OfflineStore path (authoritative local credentials).
    await requestLocalPasswordReset(email);
  }

  /// Offline password reset: create code + mailto payload.
  Future<PasswordResetRequestResult> requestLocalPasswordReset(
    String email,
  ) async {
    final store = _requireStore;
    final code = await store.beginPasswordReset(email);
    final uri = _mailtoReset(email.trim(), code);
    if (kDebugMode) {
      // Help desktop/web QA without a mail server.
      debugPrint('Watoto local password reset code for $email: $code');
    }
    return PasswordResetRequestResult(
      email: email.trim(),
      localResetCode: code,
      mailtoUri: uri,
    );
  }

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    final store = _requireStore;
    final email = store.accountEmail;
    if (email == null) throw StateError('No account on this device.');
    await store.completePasswordReset(
      email: email,
      code: code.trim(),
      newPassword: newPassword,
    );
  }

  Uri _mailtoReset(String email, String code) {
    final subject = Uri.encodeComponent('Watoto password reset code');
    final body = Uri.encodeComponent(
      'Hi,\n\n'
      'Your Watoto password reset code is:\n\n'
      '  $code\n\n'
      'Enter this code in the app (Account → Forgot password) within 1 hour.\n'
      'If you did not request this, you can ignore this message.\n\n'
      '— Watoto\n',
    );
    return Uri.parse('mailto:$email?subject=$subject&body=$body');
  }
}

/// Defaults to offline [LocalAuthService]. Bootstrap may override with
/// [createAuthService] from firebase_auth_service.dart.
final authServiceProvider = Provider<AuthService>((_) => LocalAuthService());

/// One spelled-out parental-gate challenge per app session. Overridable in
/// tests so the answer is known.
final parentGateChallengeProvider =
    Provider<ParentGateChallenge>((_) => makeParentGate());
