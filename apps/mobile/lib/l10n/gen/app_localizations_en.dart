// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Watoto';

  @override
  String homeGreeting(String name) {
    return 'Jambo, $name!';
  }

  @override
  String get dailyChallenge => 'Daily Challenge';

  @override
  String get startLearning => 'Start';

  @override
  String get subjects => 'Subjects';

  @override
  String get subjectMath => 'Math';

  @override
  String get subjectEnglish => 'English';

  @override
  String get subjectScience => 'Science';

  @override
  String get subjectArt => 'Art';

  @override
  String get lessonCountingTitle => 'Counting 1 to 3';

  @override
  String get tapToCountPrompt => 'Tap each mango to count it!';

  @override
  String get checkAnswerPrompt => 'How many mangoes did we count?';

  @override
  String get greatJob => 'Great job!';

  @override
  String get tryAgain => 'So close! Try again!';

  @override
  String get next => 'Next';

  @override
  String get done => 'Done';

  @override
  String xpEarned(int xp) {
    return '+$xp XP';
  }

  @override
  String get chooseLanguage => 'Choose your language';

  @override
  String get premiumLocked => 'Ask a grown-up to unlock';
}
