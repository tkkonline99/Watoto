import 'dart:io';

import 'package:hive/hive.dart';

/// Recovers a desktop family whose Hive data was stranded by a rename.
///
/// `getApplicationSupportDirectory()` on Windows is `%APPDATA%\{company}\
/// {product}`, so either half of that path changing points the app at an empty
/// folder while the family's boxes sit a few directories away. It has happened
/// twice: the product rename (`watoto_mobile` → `Watoto`) and the company
/// rename (`app.watoto` → `Watoto`).
///
/// **This function decides using the value the app itself stores, and it is
/// biased all the way towards doing nothing.** That is not caution for its own
/// sake — two earlier versions guessed from file sizes and both were wrong:
///
///  - gating on `account.hive` being under ~256 bytes missed the real orphan,
///    whose account box was a healthy 1 KB beside an empty progress box,
///    because the app writes an account as soon as it starts;
///  - ranking folders by "most progress bytes" then adopted a *year-old
///    abandoned* profile over the live one, because the live one had recorded
///    no progress yet. That destroyed a real family's account until it was
///    restored from a backup.
///
/// A byte count cannot tell "in use" from "large". `onboardingComplete` can,
/// so that is what is read — through Hive, not by parsing the file — and any
/// uncertainty resolves as *leave it alone*: an unreadable current profile is
/// treated as in use, and an unreadable candidate is never adopted.
///
/// Runs before `Hive.init`, is best-effort, and never blocks startup.
Future<void> migrateLegacyDesktopData(String supportPath) async {
  Directory? scratch;
  try {
    final current = Directory(supportPath);

    // Anything other than a definite "no family here" ends it. Note the
    // comparison: `null` means we could not tell, and that must not migrate.
    if (await _isOnboarded(current, () => scratch ??= _scratch()) != false) {
      return;
    }

    // Only a folder that definitely holds a family is worth adopting, and when
    // several do, the one most recently written is the one being used. Recency
    // is the tiebreak precisely because size is the signal that failed.
    Directory? best;
    DateTime? bestAt;
    for (final candidate in _candidates(current)) {
      if (await _isOnboarded(candidate, () => scratch ??= _scratch()) != true) {
        continue;
      }
      final at = _accountFile(candidate).lastModifiedSync();
      if (bestAt == null || at.isAfter(bestAt)) {
        bestAt = at;
        best = candidate;
      }
    }
    if (best == null) return;

    if (!current.existsSync()) current.createSync(recursive: true);

    // Set the current boxes aside rather than deleting them, and rename them
    // in place so a backup can never later be mistaken for a source folder.
    for (final f in current.listSync()) {
      if (f is! File || !f.path.endsWith('.hive')) continue;
      final backup = File('${f.path}.bak');
      if (backup.existsSync()) backup.deleteSync();
      f.renameSync(backup.path);
    }

    // Every box together: progress without its account would be keyed to a
    // child who does not exist in this profile.
    final sep = Platform.pathSeparator;
    for (final f in best.listSync()) {
      if (f is File && f.path.endsWith('.hive')) {
        f.copySync('$supportPath$sep${f.path.split(sep).last}');
      }
    }
  } catch (_) {
    // Best-effort only; a failed migration must never crash or stall launch.
  } finally {
    // Leave no box of ours open and no temp files behind. `bootstrap.dart`
    // calls `Hive.init(supportPath)` immediately after this returns, which
    // resets the home path a probe may have moved.
    try {
      await Hive.close();
    } catch (_) {}
    try {
      scratch?.deleteSync(recursive: true);
    } catch (_) {}
  }
}

/// Whether [dir] holds a family that finished onboarding: true, false, or null
/// when it could not be determined.
///
/// The box is inspected as a **copy** in a scratch directory. Opening a Hive
/// box writes lock files beside it and can rewrite a damaged one, and a folder
/// being examined — someone's old profile — must come out byte-identical.
Future<bool?> _isOnboarded(Directory dir, Directory Function() scratch) async {
  final src = _accountFile(dir);
  if (!src.existsSync() || src.lengthSync() == 0) return false;
  Box<String>? box;
  try {
    final sep = Platform.pathSeparator;
    final probe = Directory('${scratch().path}${sep}probe')
      ..createSync(recursive: true);
    src.copySync('${probe.path}${sep}account.hive');
    Hive.init(probe.path);
    box = await Hive.openBox<String>('account');
    if (box.get('onboardingComplete') == 'true') return true;
    // A box that opens with nothing in it, out of a file with real bytes in
    // it, has been silently *recovered* rather than read: Hive drops frames it
    // cannot parse and hands back an empty box, no error raised. Reporting
    // that as "definitely no family here" would let a damaged profile be
    // overwritten, so it counts as unknown.
    if (box.isEmpty && src.lengthSync() > 64) return null;
    return false;
  } catch (_) {
    return null;
  } finally {
    try {
      await box?.close();
    } catch (_) {}
  }
}

File _accountFile(Directory d) =>
    File('${d.path}${Platform.pathSeparator}account.hive');

Directory _scratch() =>
    Directory.systemTemp.createTempSync('watoto_migration_probe');

/// Folders that could hold this app's data, at both levels a rename can move.
///
/// Bounded deliberately: only company folders naming this app are opened, so
/// this never walks the whole of `%APPDATA%` or reads another vendor's files.
Iterable<Directory> _candidates(Directory current) sync* {
  final company = current.parent;
  if (!company.existsSync()) return;

  // A product rename: a sibling of the current folder, same company.
  for (final e in company.listSync()) {
    if (e is Directory && e.path != current.path) yield e;
  }

  // A company rename: the data is under a *different company folder*, which is
  // why a search stopping at the line above cannot find it.
  final root = company.parent;
  if (!root.existsSync() || root.path == company.path) return;
  for (final other in root.listSync()) {
    if (other is! Directory || other.path == company.path) continue;
    if (!_namesThisApp(other)) continue;
    for (final e in other.listSync()) {
      if (e is Directory) yield e;
    }
  }
}

/// Whether a company folder belongs to this app. Every name it has shipped
/// under — `app.watoto`, `Watoto` — contains the word.
bool _namesThisApp(Directory d) =>
    d.path.split(Platform.pathSeparator).last.toLowerCase().contains('watoto');
