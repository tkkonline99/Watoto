// Watoto authentication — FlutterFire (Dart) adapter.
//
// Mirrors the TypeScript module 1:1 so behaviour is identical across stacks.
// Same COPPA-aware design: children never hold credentials, a parent owns the
// account, the app starts anonymous (offline-friendly) and upgrades in place,
// a parent gate guards adult flows, child profiles store minimal data, and
// idToken() replaces the dev tokens when calling your AWS backend.
//
// Setup:
//   flutter pub add firebase_core firebase_auth cloud_firestore
//   flutterfire configure        # generates firebase_options.dart
// In main():
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//
// The only remaining step is your own Firebase project — these credentials
// cannot be generated for you.

import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const String kConsentPolicyVersion = '2026-06-01';

final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _db = FirebaseFirestore.instance;

// ----------------------------------------------------------------- session --
class WatotoAuth {
  /// Start or resume an anonymous session. Safe to call on app launch.
  static Future<User> ensureAnonymousSession() async {
    if (_auth.currentUser != null) return _auth.currentUser!;
    final cred = await _auth.signInAnonymously();
    return cred.user!;
  }

  /// Create a parent account. If a child has been playing anonymously, this
  /// upgrades that session so progress carries over. [consent] is gathered
  /// behind the parent gate and stored for the compliance record.
  static Future<User> signUpParent(
    String email,
    String password, {
    String? displayName,
    required bool consent,
  }) async {
    if (!consent) {
      throw StateError('Parental consent is required to create an account.');
    }

    User user;
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      final credential =
          EmailAuthProvider.credential(email: email, password: password);
      final result = await current.linkWithCredential(credential);
      user = result.user!;
    } else {
      final result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      user = result.user!;
    }

    if (displayName != null) await user.updateDisplayName(displayName);
    await user.sendEmailVerification();

    await _db.collection('accounts').doc(user.uid).set({
      'email': email,
      'displayName': displayName,
      'consent': {
        'granted': true,
        'policyVersion': kConsentPolicyVersion,
        'at': FieldValue.serverTimestamp(),
      },
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return user;
  }

  static Future<User> signInParent(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    return result.user!;
  }

  static Future<void> resetParentPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  static Future<void> resendVerification() async {
    final u = _auth.currentUser;
    if (u != null && !u.isAnonymous) await u.sendEmailVerification();
  }

  static Future<void> signOut() => _auth.signOut();

  /// Token to send to your AWS backend (replaces the dev token).
  ///   final token = await WatotoAuth.idToken();
  ///   // Authorization: 'Bearer $token'
  static Future<String?> idToken({bool forceRefresh = false}) =>
      _auth.currentUser?.getIdToken(forceRefresh) ?? Future.value(null);

  /// Drive navigation/state from this stream.
  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;
}

// -------------------------------------------------------------- parent gate --
class ParentGate {
  static const _words = [
    'zero', 'one', 'two', 'three', 'four',
    'five', 'six', 'seven', 'eight', 'nine'
  ];

  final String prompt; // e.g. "four — two — nine"
  final String answer; // e.g. "429"
  const ParentGate(this.prompt, this.answer);

  /// Fresh 3-digit spelled-out challenge an adult passes and a toddler won't.
  factory ParentGate.make() {
    final rng = Random();
    final digits = List.generate(3, (_) => rng.nextInt(10));
    return ParentGate(
      digits.map((d) => _words[d]).join(' — '),
      digits.join(),
    );
  }

  bool check(String input) =>
      input.replaceAll(RegExp(r'\D'), '') == answer;
}

// ------------------------------------------------------------ child profiles --
enum AgeBand { y0to1, y1to2, y2to3, y3to4, y4to5, y5to6, y6to7, y7to8, y8to9, y9to10 }

const Map<AgeBand, int> _bandToStage = {
  AgeBand.y0to1: 1, AgeBand.y1to2: 2, AgeBand.y2to3: 3, AgeBand.y3to4: 4,
  AgeBand.y4to5: 5, AgeBand.y5to6: 6, AgeBand.y6to7: 7, AgeBand.y7to8: 8,
  AgeBand.y8to9: 9, AgeBand.y9to10: 10,
};

const Map<AgeBand, String> _bandLabel = {
  AgeBand.y0to1: '0-1', AgeBand.y1to2: '1-2', AgeBand.y2to3: '2-3',
  AgeBand.y3to4: '3-4', AgeBand.y4to5: '4-5', AgeBand.y5to6: '5-6',
  AgeBand.y6to7: '6-7', AgeBand.y7to8: '7-8', AgeBand.y8to9: '8-9',
  AgeBand.y9to10: '9-10',
};

int stageForBand(AgeBand band) => _bandToStage[band]!;
String bandLabel(AgeBand band) => _bandLabel[band]!;

class ChildProfile {
  final String id;
  final String displayName; // nickname, not legal name
  final AgeBand ageBand;
  final String avatarId;
  const ChildProfile(this.id, this.displayName, this.ageBand, this.avatarId);
}

class ChildProfiles {
  static String _requireParentUid() {
    final u = _auth.currentUser;
    if (u == null || u.isAnonymous) {
      throw StateError('A signed-in parent is required to manage profiles.');
    }
    return u.uid;
  }

  static CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('accounts').doc(uid).collection('profiles');

  static Future<ChildProfile> addChild({
    required String displayName,
    required AgeBand ageBand,
    required String avatarId,
  }) async {
    final uid = _requireParentUid();
    final name = displayName.trim();
    final ref = await _col(uid).add({
      'displayName': name.length > 24 ? name.substring(0, 24) : name,
      'ageBand': bandLabel(ageBand),
      'avatarId': avatarId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ChildProfile(ref.id, name, ageBand, avatarId);
  }

  static Future<List<ChildProfile>> listChildren() async {
    final uid = _requireParentUid();
    final snap = await _col(uid).get();
    return snap.docs.map((d) {
      final data = d.data();
      final label = data['ageBand'] as String;
      final band = _bandLabel.entries.firstWhere((e) => e.value == label).key;
      return ChildProfile(
          d.id, data['displayName'] as String, band, data['avatarId'] as String);
    }).toList();
  }

  static Future<void> updateChild(String childId, Map<String, dynamic> patch) {
    final uid = _requireParentUid();
    return _col(uid).doc(childId).update(patch);
  }

  static Future<void> removeChild(String childId) {
    final uid = _requireParentUid();
    return _col(uid).doc(childId).delete();
  }
}
