// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get appTitle => 'Watoto';

  @override
  String homeGreeting(String name) {
    return 'Jambo, $name!';
  }

  @override
  String get dailyChallenge => 'Changamoto ya Leo';

  @override
  String get startLearning => 'Anza';

  @override
  String get subjects => 'Masomo';

  @override
  String get subjectMath => 'Hesabu';

  @override
  String get subjectEnglish => 'Kiingereza';

  @override
  String get subjectScience => 'Sayansi';

  @override
  String get subjectArt => 'Sanaa';

  @override
  String get lessonCountingTitle => 'Kuhesabu 1 hadi 3';

  @override
  String get tapToCountPrompt => 'Gusa kila embe ili kulihesabu!';

  @override
  String get checkAnswerPrompt => 'Tulihesabu maembe mangapi?';

  @override
  String get greatJob => 'Hongera sana!';

  @override
  String get tryAgain => 'Karibu sana! Jaribu tena!';

  @override
  String get next => 'Endelea';

  @override
  String get done => 'Maliza';

  @override
  String xpEarned(int xp) {
    return '+$xp XP';
  }

  @override
  String get chooseLanguage => 'Chagua lugha yako';

  @override
  String get premiumLocked => 'Mwombe mtu mzima akufungulie';
}
