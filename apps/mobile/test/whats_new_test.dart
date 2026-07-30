import 'package:flutter_test/flutter_test.dart';
import 'package:watoto_mobile/features/parent/whats_new.dart';

void main() {
  test('releases are newest first and include current version', () {
    expect(whatsNewReleases, isNotEmpty);
    expect(whatsNewReleases.first.version, appWhatsNewVersion);
    expect(whatsNewReleases.first.bullets, isNotEmpty);
    for (final r in whatsNewReleases) {
      expect(r.version, isNotEmpty);
      expect(r.title, isNotEmpty);
      expect(r.bullets, isNotEmpty);
    }
  });
}
