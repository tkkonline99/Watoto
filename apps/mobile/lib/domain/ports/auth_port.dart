/// Authentication port — single identity plane for UI, router, and sync.
///
/// COPPA: children never create credentialed accounts. The app may run
/// anonymously; a parent upgrades the session in place.
library;

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

/// Abstraction implemented by LocalAuth (Hive) and FirebaseAuth adapters.
abstract interface class AuthPort {
  AuthUser? get current;

  Future<AuthUser> ensureAnonymousSession();

  Future<AuthUser> signUpParent({
    required String email,
    required String password,
    required bool consent,
    String? displayName,
  });

  Future<AuthUser> signInParent({
    required String email,
    required String password,
  });

  Future<void> signOut();

  /// Bearer token for backend/Firestore. Null in pure-local mode.
  Future<String?> getIdToken({bool forceRefresh = false});

  /// Sends a password-reset email (Firebase) or dispatches a local reset code
  /// email (offline mode). Does not reveal whether the email is registered
  /// beyond generic success messaging at the UI layer when desired.
  Future<void> sendPasswordResetEmail(String email);

  /// Completes a password reset using a one-time code / OOB token.
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  });
}
