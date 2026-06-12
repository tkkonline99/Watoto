// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Watoto';

  @override
  String homeGreeting(String name) {
    return 'Jambo, $name !';
  }

  @override
  String get dailyChallenge => 'Défi du jour';

  @override
  String get startLearning => 'Commencer';

  @override
  String get subjects => 'Matières';

  @override
  String get subjectMath => 'Maths';

  @override
  String get subjectEnglish => 'Anglais';

  @override
  String get subjectScience => 'Sciences';

  @override
  String get subjectArt => 'Art';

  @override
  String get lessonCountingTitle => 'Compter de 1 à 3';

  @override
  String get tapToCountPrompt => 'Touche chaque mangue pour la compter !';

  @override
  String get checkAnswerPrompt => 'Combien de mangues avons-nous comptées ?';

  @override
  String get greatJob => 'Bravo !';

  @override
  String get tryAgain => 'Presque ! Essaie encore !';

  @override
  String get next => 'Suivant';

  @override
  String get done => 'Terminé';

  @override
  String xpEarned(int xp) {
    return '+$xp XP';
  }

  @override
  String get chooseLanguage => 'Choisis ta langue';

  @override
  String get premiumLocked => 'Demande à un adulte de déverrouiller';
}
