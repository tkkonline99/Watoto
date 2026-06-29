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
    return 'Hello, $name!';
  }

  @override
  String get dailyChallenge => 'Daily Challenge';

  @override
  String get startLearning => 'Start';

  @override
  String get subjects => 'Subjects';

  @override
  String get selectAgeTitle => 'How old are you?';

  @override
  String get selectAgeSubtitle => 'Pick an age to see the right activities.';

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

  @override
  String get quizTime => 'Quiz time!';

  @override
  String get quizCountingTitle => 'Counting Quiz';

  @override
  String get quizHowMany => 'How many do you see?';

  @override
  String quizScore(int correct, int total) {
    return 'You got $correct of $total!';
  }

  @override
  String get retry => 'Try again';

  @override
  String get consentTitle => 'A safe place to learn';

  @override
  String get consentBody =>
      'Watoto has no ads and no chat. We only collect what is needed to save your child\'s progress. As the grown-up, you choose what to turn on.';

  @override
  String get consentCoreData => 'Save learning progress';

  @override
  String get consentRequired => 'Required to use the app';

  @override
  String get consentAi => 'AI Tutor & helpers';

  @override
  String get consentAiBody => 'Personalized help and explanations';

  @override
  String get consentVoice => 'Voice recording';

  @override
  String get consentVoiceBody =>
      'For reading practice; audio is deleted within 30 days';

  @override
  String get consentChangeLater =>
      'You can change these anytime in the Parent Zone.';

  @override
  String get agreeContinue => 'Agree & continue';

  @override
  String get setPinTitle => 'Set a parent PIN';

  @override
  String get setPinSubtitle =>
      'This keeps settings and the Parent Zone for grown-ups only.';

  @override
  String get parentPin => 'PIN';

  @override
  String get confirmPin => 'Confirm PIN';

  @override
  String get pinTooShort => 'Use at least 4 digits';

  @override
  String get pinMismatch => 'PINs do not match';

  @override
  String get enterPinTitle => 'Grown-ups only';

  @override
  String get enterPinSubtitle => 'Enter your parent PIN to continue.';

  @override
  String get wrongPin => 'Wrong PIN, try again';

  @override
  String get unlock => 'Unlock';

  @override
  String get createChildTitle => 'Add your child';

  @override
  String get createChildSubtitle =>
      'Pick a fun name and an animal buddy to learn with!';

  @override
  String get childNickname => 'Nickname';

  @override
  String get childNicknameHint => 'What should we call them?';

  @override
  String get chooseAvatar => 'Choose an animal';

  @override
  String childAge(int age, String band) {
    return 'Age $age ($band)';
  }

  @override
  String get whoIsLearning => 'Who is learning?';

  @override
  String get addChild => 'Add child';

  @override
  String get parentZone => 'Parent Zone';

  @override
  String get children => 'Children';

  @override
  String ageBandLabel(String band) {
    return 'Ages $band';
  }

  @override
  String lessonsDone(int count) {
    return '$count lessons';
  }

  @override
  String get privacyData => 'Privacy & data';

  @override
  String get switchChild => 'Switch child';

  @override
  String get lockParentZone => 'Lock';

  @override
  String get storybooks => 'Storybooks';

  @override
  String get textSize => 'Text size';

  @override
  String get theEnd => 'The End!';

  @override
  String get readAgain => 'Read again';

  @override
  String get curriculum => 'Curriculum';

  @override
  String get forGrownups => 'For grown-ups';

  @override
  String get grownupCheck => 'Grown-up check';

  @override
  String get grownupCheckBody =>
      'Ask a grown-up to continue. Type these numbers:';

  @override
  String get gateAnswerHint => 'Type the answer';

  @override
  String get wrongNumbers => 'Those numbers don\'t match — try again';

  @override
  String stageOf(int stage, String ages) {
    return 'Stage $stage · Ages $ages';
  }

  @override
  String get legalSection => 'About & legal';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get legalDraftNote => 'Draft — pending legal review';
}
