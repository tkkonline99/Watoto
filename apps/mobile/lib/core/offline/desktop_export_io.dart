import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Writes the family JSON export next to Documents/Downloads on desktop so
/// parents can open it in Explorer (clipboard alone is awkward on Windows).
///
/// Returns the absolute path written, or null on failure.
Future<String?> writeFamilyExportFile(String json) async {
  try {
    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {
      dir = null;
    }
    dir ??= await getApplicationDocumentsDirectory();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File('${dir.path}${Platform.pathSeparator}watoto-export-$stamp.json');
    await file.writeAsString(json, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}

/// Saves a rendered certificate PNG somewhere a family can actually find it
/// (Downloads, else Documents). Returns the absolute path, or null on failure.
///
/// A certificate nobody can show to anyone is just a screen; getting it out of
/// the app is the whole point of the feature.
Future<String?> writeCertificateImage(Uint8List png, String childName) async {
  try {
    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {
      dir = null;
    }
    dir ??= await getApplicationDocumentsDirectory();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final safeName = childName
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .trim()
        .replaceAll(' ', '-');
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(
      '${dir.path}${Platform.pathSeparator}'
      'watoto-certificate-${safeName.isEmpty ? 'child' : safeName}-$stamp.png',
    );
    await file.writeAsBytes(png, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}
