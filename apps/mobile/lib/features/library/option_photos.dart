/// Photographs that stand in for a lexicon glyph.
///
/// Most of the library draws a word as an emoji, which is the right default:
/// emoji are language-neutral, free, and consistent. But a photograph of a real
/// dog teaches "dog" in a way 🐶 does not, and for the animals a child meets
/// first that difference is the lesson.
///
/// So this is a *supplement*, never a replacement. Any word without a photo
/// keeps its glyph, and a photo that fails to load falls back to the glyph too
/// — the picture always arrives, which is what docs/26 §26.3 requires.
///
/// Words are mapped explicitly rather than by naming convention. A convention
/// would mean every one of the 250-odd glyph options attempting an asset load
/// that will not resolve, just to learn there is no photo for "worried".
///
/// Sources live outside the repo and are prepared by `content/prep_photos.py`,
/// which crops each one so it survives the disc's circular mask and re-encodes
/// it as JPEG — as PNG the same three came to 844 KB.
library;

/// Bundled photograph for [word], or null to use its glyph.
///
/// Words sharing an emoji share a photo: `dog` and `puppy` are both 🐶 in the
/// lexicon, so a lesson that stages them together would otherwise offer the
/// same answer twice — once as a photo and once as a glyph.
String? optionPhotoAsset(String word) => _photos[word.toLowerCase()];

const _photos = <String, String>{
  'dog': 'assets/images/img/photo/dog.jpg',
  'puppy': 'assets/images/img/photo/dog.jpg',
  'chicken': 'assets/images/img/photo/chicken.jpg',
  'owl': 'assets/images/img/photo/owl.jpg',
};

/// Every distinct file the registry names, for the bundling guard in
/// test/option_photos_test.dart.
Iterable<String> get bundledOptionPhotos => _photos.values.toSet();
