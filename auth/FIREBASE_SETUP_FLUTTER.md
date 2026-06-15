# Watoto Auth — Flutter / FlutterFire port

The files in this folder (`firebase.ts`, `auth.ts`, `childProfiles.ts`,
`parentGate.ts`, `index.ts`) are the reference design, written for **React
Native / Expo + the Firebase JS SDK**. The Watoto app is **Flutter/Dart**, so
the same design is implemented in Dart:

| Reference (TS / Expo) | Flutter implementation |
|---|---|
| `parentGate.ts` | `apps/mobile/lib/features/auth/parent_gate.dart` (done, tested) |
| `auth.ts` interface | `apps/mobile/lib/features/auth/auth_service.dart` — `AuthService` seam + `LocalAuthService` default (done, tested) |
| `firebase.ts` / Firebase impl | `FirebaseAuthService` — add when you create your Firebase project (below) |
| `childProfiles.ts` | already covered by the in-app child profiles (`OfflineStore`); moves under the parent uid once Firebase is live |
| backend token verify | `apps/api` — verify the Firebase ID token instead of the dev token |

The app already works offline today via `LocalAuthService` (anonymous session,
no accounts, dev-token API path). The **only** thing that needs *your* input is
creating the Firebase project — everything else is ready behind the seam.

## Activate Firebase (about 15 minutes)

1. Create a Firebase project; enable **Email/Password** and **Anonymous**
   sign-in; create a **Firestore** database.
2. Add FlutterFire to the app:
   ```bash
   cd apps/mobile
   flutter pub add firebase_core firebase_auth cloud_firestore
   dart pub global activate flutterfire_cli
   flutterfire configure        # writes lib/firebase_options.dart
   ```
3. Drop in the adapter below as
   `apps/mobile/lib/features/auth/firebase_auth_service.dart`.
4. Flip the provider in `auth_service.dart`:
   ```dart
   final authServiceProvider = Provider<AuthService>((_) => FirebaseAuthService());
   ```
5. Initialize Firebase in `main.dart`:
   ```dart
   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
   await container.read(authServiceProvider).ensureAnonymousSession();
   ```
6. Make backend calls carry the ID token (replaces the dev token):
   ```dart
   final token = await ref.read(authServiceProvider).getIdToken();
   // Authorization: 'Bearer $token'
   ```
   The AWS backend (`apps/api`) then verifies it — `firebase-admin`
   `verifyIdToken(token)`, or validate the JWT against Google's public keys
   (`iss = https://securetoken.google.com/<projectId>`, `aud = <projectId>`).

## Adapter (`firebase_auth_service.dart`)

```dart
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  final _auth = fb.FirebaseAuth.instance;

  AuthUser _map(fb.User u) => AuthUser(
        uid: u.uid, email: u.email,
        isAnonymous: u.isAnonymous, emailVerified: u.emailVerified);

  @override
  AuthUser? get current {
    final u = _auth.currentUser;
    return u == null ? null : _map(u);
  }

  @override
  Future<AuthUser> ensureAnonymousSession() async {
    final u = _auth.currentUser ?? (await _auth.signInAnonymously()).user!;
    return _map(u);
  }

  @override
  Future<AuthUser> signUpParent({
    required String email, required String password,
    required bool consent, String? displayName,
  }) async {
    if (!consent) throw StateError('Parental consent is required.');
    final current = _auth.currentUser;
    late fb.User user;
    if (current != null && current.isAnonymous) {
      final cred = fb.EmailAuthProvider.credential(email: email, password: password);
      user = (await current.linkWithCredential(cred)).user!; // upgrade in place
    } else {
      user = (await _auth.createUserWithEmailAndPassword(
              email: email, password: password)).user!;
    }
    if (displayName != null) await user.updateDisplayName(displayName);
    await user.sendEmailVerification();
    // also write parents/{uid} consent doc via cloud_firestore (policy version)
    return _map(user);
  }

  @override
  Future<AuthUser> signInParent({required String email, required String password}) async =>
      _map((await _auth.signInWithEmailAndPassword(
              email: email, password: password)).user!);

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) =>
      _auth.currentUser?.getIdToken(forceRefresh) ?? Future.value(null);
}
```

## Lock down Firestore

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    match /parents/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
      match /children/{childId} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
    }
  }
}
```
