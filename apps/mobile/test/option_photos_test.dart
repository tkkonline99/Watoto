import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/library/content_lexicon.dart';
import 'package:watoto_mobile/features/library/option_photos.dart';
import 'package:watoto_mobile/features/library/play_stages.dart';
import 'package:watoto_mobile/l10n/gen/app_localizations.dart';

/// Photographs standing in for a lexicon glyph.
///
/// The failure mode this guards is the one the pubspec comment warns about:
/// asset directories are not recursive, so a registry entry whose folder was
/// never listed resolves to nothing and every photo silently becomes an emoji
/// again — with no error anywhere, because falling back to the glyph is the
/// designed behaviour for a photo that will not load.

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every photo the registry names is on disk and bundled', () async {
    final declared = File('pubspec.yaml').readAsStringSync();
    expect(
      declared,
      contains('assets/images/img/photo/'),
      reason: 'the folder is not listed in pubspec assets, so nothing in it '
          'ships and every photo falls back to its emoji',
    );
    for (final path in bundledOptionPhotos) {
      expect(File(path).existsSync(), isTrue, reason: '$path is missing');
      // Loadable through the bundle, not merely present on disk.
      final bytes = await rootBundle.load(path);
      expect(bytes.lengthInBytes, greaterThan(0), reason: '$path is empty');
      // A photograph, kept small on purpose — see content/prep_photos.py.
      expect(
        bytes.lengthInBytes,
        lessThan(120 * 1024),
        reason: '$path is ${bytes.lengthInBytes ~/ 1024} KB; the art pack '
            'averages 28 KB a file',
      );
    }
  });

  test('a photographed word is a real, choosable lexicon word', () {
    for (final word in ['dog', 'puppy', 'chicken', 'owl']) {
      final entry = lexiconLookup(word);
      expect(entry, isNotNull, reason: '$word left the lexicon');
      expect(entry!.choice, isTrue,
          reason: '$word can no longer be staged as an answer');
      expect(optionPhotoAsset(word), isNotNull);
    }
  });

  test('words sharing an emoji share a photo', () {
    // Otherwise a step staging both offers the same animal twice, once as a
    // photograph and once as a glyph.
    expect(lexiconLookup('dog')!.emoji, lexiconLookup('puppy')!.emoji);
    expect(optionPhotoAsset('dog'), optionPhotoAsset('puppy'));
  });

  test('an unphotographed word keeps its glyph', () {
    expect(optionPhotoAsset('cat'), isNull);
    expect(optionPhotoAsset('worried'), isNull);
    expect(optionPhotoAsset('bookse'), isNull);
  });

  testWidgets('the disc draws the photo, and the glyph when there is none',
      (tester) async {
    await tester.pumpWidget(_host(
      AnswerPictureDisc(glyph: '🐶', photoAsset: optionPhotoAsset('dog')),
    ));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image)).image;
    expect((image as AssetImage).assetName, contains('dog.jpg'));
    expect(find.text('🐶'), findsNothing);

    await tester.pumpWidget(_host(
      AnswerPictureDisc(glyph: '🐱', photoAsset: optionPhotoAsset('cat')),
    ));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.text('🐱'), findsOneWidget);
  });
}
