import 'dart:io';

/// One-time migration shim. The Windows product-name change (branding unify)
/// moved `getApplicationSupportDirectory()` to a new folder, which orphaned the
/// family's Hive data and silently forced re-onboarding on every new build.
///
/// If [supportPath] has no real account box yet, copy the Hive boxes from the
/// richest sibling folder that does (e.g. the old `…\watoto_mobile` dir). Runs
/// before `Hive.init`, is best-effort, and never blocks startup.
Future<void> migrateLegacyDesktopData(String supportPath) async {
  try {
    final current = Directory(supportPath);
    final sep = Platform.pathSeparator;
    final currentAccount = File('$supportPath${sep}account.hive');
    // A locale-only account box is ~80 bytes; an onboarded one is larger, so a
    // small threshold distinguishes "already has a family" from "fresh".
    if (currentAccount.existsSync() && currentAccount.lengthSync() > 256) return;

    final parent = current.parent;
    if (!parent.existsSync()) return;

    Directory? best;
    var bestLen = 256;
    for (final e in parent.listSync()) {
      if (e is! Directory || e.path == current.path) continue;
      final acc = File('${e.path}${sep}account.hive');
      if (acc.existsSync() && acc.lengthSync() > bestLen) {
        bestLen = acc.lengthSync();
        best = e;
      }
    }
    if (best == null) return;

    if (!current.existsSync()) current.createSync(recursive: true);
    for (final f in best.listSync()) {
      // Copy the boxes only (not the .lock files Hive recreates).
      if (f is File && f.path.endsWith('.hive')) {
        final name = f.path.split(sep).last;
        f.copySync('$supportPath$sep$name');
      }
    }
  } catch (_) {
    // Best-effort only; a failed migration must never crash or stall launch.
  }
}
