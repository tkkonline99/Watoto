// File generated-compatible stub for FlutterFire CLI (`flutterfire configure`).
// Replace this file by running:
//   flutterfire configure --project=<your-firebase-project-id> --out=lib/firebase_options.dart
// or pass `--dart-define=FIREBASE_PROJECT_ID=...` at build time.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static const String _unconfiguredToken = 'UNCONFIGURED';

  static const String _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: _unconfiguredToken,
  );
  static const String _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '000000000000',
  );
  static const String _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'watoto-unconfigured.appspot.com',
  );

  /// True when real Firebase project credentials have been supplied either by
  /// running `flutterfire configure` (replacing [_projectId] / platform keys)
  /// or via `--dart-define=FIREBASE_PROJECT_ID=...` and `FIREBASE_API_KEY=...`.
  static bool get isConfigured {
    try {
      final opts = currentPlatform;
      return opts.projectId.isNotEmpty &&
          opts.projectId != _unconfiguredToken &&
          opts.apiKey.isNotEmpty &&
          !opts.apiKey.startsWith(_unconfiguredToken);
    } on UnsupportedError {
      return false;
    }
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_WEB_API_KEY',
      defaultValue: String.fromEnvironment(
        'FIREBASE_API_KEY',
        defaultValue: _unconfiguredToken,
      ),
    ),
    appId: String.fromEnvironment(
      'FIREBASE_WEB_APP_ID',
      defaultValue: String.fromEnvironment(
        'FIREBASE_APP_ID',
        defaultValue: '1:000000000000:web:0000000000000000',
      ),
    ),
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: String.fromEnvironment(
      'FIREBASE_AUTH_DOMAIN',
      defaultValue: 'watoto-unconfigured.firebaseapp.com',
    ),
    storageBucket: _storageBucket,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY',
      defaultValue: String.fromEnvironment(
        'FIREBASE_API_KEY',
        defaultValue: _unconfiguredToken,
      ),
    ),
    appId: String.fromEnvironment(
      'FIREBASE_ANDROID_APP_ID',
      defaultValue: String.fromEnvironment(
        'FIREBASE_APP_ID',
        defaultValue: '1:000000000000:android:0000000000000000',
      ),
    ),
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_IOS_API_KEY',
      defaultValue: String.fromEnvironment(
        'FIREBASE_API_KEY',
        defaultValue: _unconfiguredToken,
      ),
    ),
    appId: String.fromEnvironment(
      'FIREBASE_IOS_APP_ID',
      defaultValue: String.fromEnvironment(
        'FIREBASE_APP_ID',
        defaultValue: '1:000000000000:ios:0000000000000000',
      ),
    ),
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    iosBundleId: String.fromEnvironment(
      'FIREBASE_IOS_BUNDLE_ID',
      defaultValue: 'com.watoto.watotoMobile',
    ),
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_MACOS_API_KEY',
      defaultValue: String.fromEnvironment(
        'FIREBASE_API_KEY',
        defaultValue: _unconfiguredToken,
      ),
    ),
    appId: String.fromEnvironment(
      'FIREBASE_MACOS_APP_ID',
      defaultValue: String.fromEnvironment(
        'FIREBASE_APP_ID',
        defaultValue: '1:000000000000:ios:0000000000000000',
      ),
    ),
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    iosBundleId: String.fromEnvironment(
      'FIREBASE_IOS_BUNDLE_ID',
      defaultValue: 'com.watoto.watotoMobile',
    ),
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_WINDOWS_API_KEY',
      defaultValue: String.fromEnvironment(
        'FIREBASE_API_KEY',
        defaultValue: _unconfiguredToken,
      ),
    ),
    appId: String.fromEnvironment(
      'FIREBASE_WINDOWS_APP_ID',
      defaultValue: String.fromEnvironment(
        'FIREBASE_APP_ID',
        defaultValue: '1:000000000000:web:0000000000000000',
      ),
    ),
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: String.fromEnvironment(
      'FIREBASE_AUTH_DOMAIN',
      defaultValue: 'watoto-unconfigured.firebaseapp.com',
    ),
    storageBucket: _storageBucket,
  );
}
