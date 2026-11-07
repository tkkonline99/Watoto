/// Firebase initialization seam — initializes [Firebase] when
/// [DefaultFirebaseOptions.isConfigured] (or `WATOTO_CLOUD_AUTH=true`) is set,
/// and degrades cleanly to offline mode otherwise.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../features/auth/firebase_auth_service.dart';
import '../firebase_options.dart';

bool _firebaseInitialized = false;

/// True after [initializeWatotoFirebase] has successfully initialized a live
/// [FirebaseApp] (or when overridden in tests via [debugSetFirebaseInitialized]).
bool get isFirebaseInitialized => _firebaseInitialized;

/// Overrides [isFirebaseInitialized] in unit tests.
@visibleForTesting
void debugSetFirebaseInitialized(bool value) {
  _firebaseInitialized = value;
}

/// Initializes Firebase when [DefaultFirebaseOptions.isConfigured] or
/// [isCloudAuthBuild] is true. Returns true if Firebase was initialized.
Future<bool> initializeWatotoFirebase({FirebaseOptions? options}) async {
  if (_firebaseInitialized) return true;
  final configured = options != null || DefaultFirebaseOptions.isConfigured;
  if (!isCloudAuthBuild && !configured) {
    return false;
  }
  if (!configured) {
    return false;
  }
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: options ?? DefaultFirebaseOptions.currentPlatform,
      );
    }
    _firebaseInitialized = true;
    return true;
  } catch (e) {
    debugPrint('Watoto Firebase initialization skipped (offline fallback): $e');
    _firebaseInitialized = false;
    return false;
  }
}
