/// Firebase initialization seam — no-op until FlutterFire is configured.
///
/// After `flutterfire configure`, replace [initializeWatotoFirebase] with:
/// ```dart
/// import 'package:firebase_core/firebase_core.dart';
/// import '../firebase_options.dart';
/// Future<void> initializeWatotoFirebase() async {
///   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
/// }
/// ```
library;

import '../features/auth/firebase_auth_service.dart';

/// Initializes Firebase when this build is a cloud auth build.
/// Returns true if Firebase was initialized.
Future<bool> initializeWatotoFirebase() async {
  if (!isCloudAuthBuild) return false;
  // Packages + options not present in the default offline publish tree.
  // setup_firebase.md walks through enabling them without rewriting callers.
  return false;
}
