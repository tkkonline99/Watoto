import 'dart:typed_data';

/// Web / mobile: no desktop file path; callers keep clipboard-only export.
Future<String?> writeFamilyExportFile(String json) async => null;

/// Web / mobile: no writable Downloads folder to drop a certificate into.
Future<String?> writeCertificateImage(Uint8List png, String childName) async =>
    null;
