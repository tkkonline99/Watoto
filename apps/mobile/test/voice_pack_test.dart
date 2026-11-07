import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:watoto_mobile/core/audio/voice_pack_service.dart';
import 'package:watoto_mobile/core/offline/offline_store.dart';

Uint8List _buildTestZip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final e in files.entries) {
    archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('watoto_voice_pack_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('downloads, verifies SHA-256, extracts MP3s, and resolves clips', () async {
    final store = await OfflineStore.open(inMemory: true);
    final zipBytes = _buildTestZip({
      's01.cause.lesson.01.steps.0.narration.mp3': [0x49, 0x44, 0x33, 1, 2, 3],
      'nested/s01.animals.story.01.pages.0.narration.mp3': [0x49, 0x44, 0x33, 4, 5],
      '../evil.mp3': [9, 9, 9],
      'readme.txt': [65, 66],
    });
    final expectedHash = sha256.convert(zipBytes).toString();

    final mockHttp = MockClient((req) async {
      expect(req.url.path, endsWith('/sw.zip'));
      return http.Response.bytes(zipBytes, 200);
    });

    final svc = VoicePackService(
      store: store,
      httpClient: mockHttp,
      baseDirProvider: () async => tempDir,
      baseUrl: 'https://example.com/voice-pack-v1',
    );

    expect(svc.isInstalled('sw'), isFalse);
    final count = await svc.downloadAndInstall(
      'sw',
      expectedSha256: expectedHash,
    );
    expect(count, 2);
    expect(svc.isInstalled('sw'), isTrue);
    expect(svc.installedClipCount('sw'), 2);

    final resolved = svc.resolveDownloadedClip(
      'sw',
      's01.cause.lesson.01.steps.0.narration',
    );
    expect(resolved, isNotNull);
    expect(File(resolved!).existsSync(), isTrue);

    // Ensure zip-slip entry was ignored.
    expect(svc.resolveDownloadedClip('sw', 'evil'), isNull);

    await svc.removePack('sw');
    expect(svc.isInstalled('sw'), isFalse);
    expect(
      svc.resolveDownloadedClip('sw', 's01.cause.lesson.01.steps.0.narration'),
      isNull,
    );
  });

  test('rejects archive when SHA-256 digest does not match', () async {
    final store = await OfflineStore.open(inMemory: true);
    final zipBytes = _buildTestZip({
      's01.cause.lesson.01.steps.0.narration.mp3': [1, 2, 3, 4],
    });

    final mockHttp = MockClient((_) async => http.Response.bytes(zipBytes, 200));
    final svc = VoicePackService(
      store: store,
      httpClient: mockHttp,
      baseDirProvider: () async => tempDir,
    );

    await expectLater(
      svc.downloadAndInstall(
        'en',
        expectedSha256:
            '0000000000000000000000000000000000000000000000000000000000000000',
      ),
      throwsFormatException,
    );
    expect(svc.isInstalled('en'), isFalse);
  });
}
