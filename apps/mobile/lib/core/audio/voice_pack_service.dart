/// Downloadable neural voiceover pack manager (Parent Zone only).
///
/// Families on devices without a stock Swahili or French TTS voice — or
/// parents who want the studio-warm neural voiceover (`en-US-AnaNeural`,
/// `sw-KE-ZuriNeural`, `fr-FR-EloiseNeural`) offline — can download a per-
/// language `.zip` pack from the `voice-pack-v1` release without bloating the
/// base Play Store / App Store download.
///
/// Lookup order in [NarrationController]:
///   1. Bundled asset (`assets/audio/<lang>/<audioKey>.mp3`)
///   2. Downloaded voice pack file (`<appSupport>/voice_packs/<lang>/<audioKey>.mp3`)
///   3. On-device [FlutterTts]
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../offline/offline_providers.dart';

/// Default GitHub Release base URL hosting `en.zip`, `sw.zip`, `fr.zip`, and
/// `voice_pack_index.json`. Overridable via `--dart-define=WATOTO_VOICE_PACK_BASE_URL=...`.
const defaultVoicePackBaseUrl = String.fromEnvironment(
  'WATOTO_VOICE_PACK_BASE_URL',
  defaultValue:
      'https://github.com/tkkonline99/Watoto/releases/download/voice-pack-v1',
);

/// Metadata describing one language's neural voiceover pack.
class VoicePackCatalogEntry {
  const VoicePackCatalogEntry({
    required this.langCode,
    required this.voiceName,
    required this.approxSizeMb,
  });

  final String langCode;
  final String voiceName;
  final int approxSizeMb;
}

const voicePackCatalog = <VoicePackCatalogEntry>[
  VoicePackCatalogEntry(
    langCode: 'en',
    voiceName: 'Ana Neural (en-US)',
    approxSizeMb: 18,
  ),
  VoicePackCatalogEntry(
    langCode: 'sw',
    voiceName: 'Zuri Neural (sw-KE)',
    approxSizeMb: 18,
  ),
  VoicePackCatalogEntry(
    langCode: 'fr',
    voiceName: 'Eloise Neural (fr-FR)',
    approxSizeMb: 18,
  ),
];

/// Manages downloading, verifying (SHA-256), extracting, and resolving
/// offline neural voiceover MP3 clips per language (`en`, `sw`, `fr`).
class VoicePackService {
  VoicePackService({
    required OfflineStore store,
    http.Client? httpClient,
    Future<Directory> Function()? baseDirProvider,
    this.baseUrl = defaultVoicePackBaseUrl,
  }) : _http = httpClient ?? http.Client(),
       _baseDirProvider = baseDirProvider ?? getApplicationSupportDirectory {
    _store = store;
  }

  late final OfflineStore _store;
  final http.Client _http;
  final Future<Directory> Function() _baseDirProvider;
  final String baseUrl;

  Directory? _cachedRootDir;
  final Map<String, Set<String>> _installedKeys = {};
  final Set<String> _downloading = {};

  /// Supported on native targets (iOS, Android, macOS, Windows, Linux).
  bool get isSupported => !kIsWeb;

  bool isDownloading(String langCode) => _downloading.contains(langCode);

  bool isInstalled(String langCode) => _store.isVoicePackInstalled(langCode);

  int installedClipCount(String langCode) =>
      _store.voicePackClipCount(langCode);

  Future<Directory> _rootDir() async {
    if (_cachedRootDir != null) return _cachedRootDir!;
    final support = await _baseDirProvider();
    final dir = Directory('${support.path}/voice_packs');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _cachedRootDir = dir;
    return dir;
  }

  /// Registers an already-known directory and clip set in memory (used at boot
  /// or in unit tests).
  void registerInstalledClips(
    String langCode,
    Directory rootDir,
    Iterable<String> audioKeys,
  ) {
    _cachedRootDir = rootDir;
    _installedKeys[langCode] = {
      for (final k in audioKeys) k.replaceFirst(RegExp(r'\.mp3$'), '').trim(),
    };
  }

  /// Resolves the absolute filesystem path for [audioKey] in [langCode] if a
  /// downloaded voice pack has that clip on disk, or null otherwise.
  String? resolveDownloadedClip(
    String langCode,
    String? audioKey, {
    bool allowEnglishFallback = false,
  }) {
    if (kIsWeb || audioKey == null || audioKey.trim().isEmpty) return null;
    final root = _cachedRootDir;
    if (root == null) return null;
    final key = audioKey.trim().replaceFirst(RegExp(r'\.mp3$'), '');

    String? checkLang(String lang) {
      final known = _installedKeys[lang];
      if (known != null && !known.contains(key)) return null;
      final file = File('${root.path}/$lang/$key.mp3');
      if (file.existsSync()) {
        (_installedKeys[lang] ??= {}).add(key);
        return file.path;
      }
      return null;
    }

    final primary = checkLang(langCode);
    if (primary != null) return primary;
    if (allowEnglishFallback && langCode != 'en') {
      return checkLang('en');
    }
    return null;
  }

  /// Scans `<appSupport>/voice_packs/` on startup so previously downloaded
  /// packs are immediately available to [resolveDownloadedClip].
  Future<void> warmUpIndex() async {
    if (kIsWeb) return;
    try {
      final root = await _rootDir();
      for (final entry in voicePackCatalog) {
        final langDir = Directory('${root.path}/${entry.langCode}');
        if (!langDir.existsSync()) continue;
        final keys = <String>{};
        await for (final entity in langDir.list(followLinks: false)) {
          if (entity is File && entity.path.toLowerCase().endsWith('.mp3')) {
            final name = entity.uri.pathSegments.last;
            keys.add(name.substring(0, name.length - 4));
          }
        }
        _installedKeys[entry.langCode] = keys;
        if (keys.isNotEmpty && !_store.isVoicePackInstalled(entry.langCode)) {
          await _store.setVoicePackInstalled(
            entry.langCode,
            installed: true,
            clipCount: keys.length,
          );
        }
      }
    } catch (_) {
      // Ignore filesystem errors in test environments without path_provider.
    }
  }

  /// Downloads `<baseUrl>/<langCode>.zip`, verifies [expectedSha256] when
  /// provided, extracts `.mp3` clips into `<appSupport>/voice_packs/<langCode>/`,
  /// and updates [OfflineStore].
  Future<int> downloadAndInstall(
    String langCode, {
    String? expectedSha256,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Offline voice packs are not supported on Web.');
    }
    if (_downloading.contains(langCode)) {
      return installedClipCount(langCode);
    }
    _downloading.add(langCode);
    try {
      final uri = Uri.parse('$baseUrl/$langCode.zip');
      final response = await _http
          .get(uri)
          .timeout(const Duration(minutes: 3));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Voice pack download failed (${response.statusCode})',
          uri: uri,
        );
      }
      final bytes = response.bodyBytes;
      if (expectedSha256 != null && expectedSha256.trim().isNotEmpty) {
        final digest = sha256.convert(bytes).toString().toLowerCase();
        if (digest != expectedSha256.trim().toLowerCase()) {
          throw const FormatException('Voice pack SHA-256 digest mismatch.');
        }
      }

      final archive = ZipDecoder().decodeBytes(bytes);
      final root = await _rootDir();
      final langDir = Directory('${root.path}/$langCode');
      if (!langDir.existsSync()) {
        await langDir.create(recursive: true);
      }

      final extractedKeys = <String>{};
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final normalized = file.name.replaceAll('\\', '/');
        if (normalized.contains('..')) continue; // guard against zip-slip
        final baseName = normalized.split('/').last;
        if (!baseName.toLowerCase().endsWith('.mp3')) continue;
        final outFile = File('${langDir.path}/$baseName');
        final content = file.content as List<int>;
        await outFile.writeAsBytes(content, flush: true);
        extractedKeys.add(baseName.substring(0, baseName.length - 4));
      }

      _installedKeys[langCode] = extractedKeys;
      await _store.setVoicePackInstalled(
        langCode,
        installed: extractedKeys.isNotEmpty,
        clipCount: extractedKeys.length,
      );
      return extractedKeys.length;
    } finally {
      _downloading.remove(langCode);
    }
  }

  /// Deletes all extracted MP3 files for [langCode] and marks it uninstalled.
  Future<void> removePack(String langCode) async {
    _installedKeys.remove(langCode);
    await _store.setVoicePackInstalled(langCode, installed: false);
    if (kIsWeb) return;
    try {
      final root = await _rootDir();
      final langDir = Directory('${root.path}/$langCode');
      if (langDir.existsSync()) {
        await langDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}

/// Bumped whenever a voice pack is installed or removed so Parent Zone UI
/// rebuilds.
final voicePackTickProvider = StateProvider<int>((_) => 0);

final voicePackServiceProvider = Provider<VoicePackService>((ref) {
  final store = ref.watch(offlineStoreProvider);
  return VoicePackService(store: store);
});
