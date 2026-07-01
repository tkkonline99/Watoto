import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('sw'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Watoto'**
  String get appTitle;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}!'**
  String homeGreeting(String name);

  /// No description provided for @dailyChallenge.
  ///
  /// In en, this message translates to:
  /// **'Daily Challenge'**
  String get dailyChallenge;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What shall we play today?'**
  String get homeSubtitle;

  /// No description provided for @startLearning.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startLearning;

  /// No description provided for @subjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get subjects;

  /// No description provided for @selectAgeTitle.
  ///
  /// In en, this message translates to:
  /// **'How old are you?'**
  String get selectAgeTitle;

  /// No description provided for @selectAgeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick an age to see the right activities.'**
  String get selectAgeSubtitle;

  /// No description provided for @subjectMath.
  ///
  /// In en, this message translates to:
  /// **'Math'**
  String get subjectMath;

  /// No description provided for @subjectEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get subjectEnglish;

  /// No description provided for @subjectScience.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get subjectScience;

  /// No description provided for @subjectArt.
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get subjectArt;

  /// No description provided for @lessonCountingTitle.
  ///
  /// In en, this message translates to:
  /// **'Counting 1 to 3'**
  String get lessonCountingTitle;

  /// No description provided for @tapToCountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Tap each mango to count it!'**
  String get tapToCountPrompt;

  /// No description provided for @checkAnswerPrompt.
  ///
  /// In en, this message translates to:
  /// **'How many mangoes did we count?'**
  String get checkAnswerPrompt;

  /// No description provided for @greatJob.
  ///
  /// In en, this message translates to:
  /// **'Great job!'**
  String get greatJob;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'So close! Try again!'**
  String get tryAgain;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @xpEarned.
  ///
  /// In en, this message translates to:
  /// **'+{xp} XP'**
  String xpEarned(int xp);

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguage;

  /// No description provided for @premiumLocked.
  ///
  /// In en, this message translates to:
  /// **'Ask a grown-up to unlock'**
  String get premiumLocked;

  /// No description provided for @quizTime.
  ///
  /// In en, this message translates to:
  /// **'Quiz time!'**
  String get quizTime;

  /// No description provided for @quizCountingTitle.
  ///
  /// In en, this message translates to:
  /// **'Counting Quiz'**
  String get quizCountingTitle;

  /// No description provided for @quizHowMany.
  ///
  /// In en, this message translates to:
  /// **'How many do you see?'**
  String get quizHowMany;

  /// No description provided for @quizScore.
  ///
  /// In en, this message translates to:
  /// **'You got {correct} of {total}!'**
  String quizScore(int correct, int total);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'A safe place to learn'**
  String get consentTitle;

  /// No description provided for @consentBody.
  ///
  /// In en, this message translates to:
  /// **'Watoto has no ads and no chat. We only collect what is needed to save your child\'s progress. As the grown-up, you choose what to turn on.'**
  String get consentBody;

  /// No description provided for @consentCoreData.
  ///
  /// In en, this message translates to:
  /// **'Save learning progress'**
  String get consentCoreData;

  /// No description provided for @consentRequired.
  ///
  /// In en, this message translates to:
  /// **'Required to use the app'**
  String get consentRequired;

  /// No description provided for @consentAi.
  ///
  /// In en, this message translates to:
  /// **'AI Tutor & helpers'**
  String get consentAi;

  /// No description provided for @consentAiBody.
  ///
  /// In en, this message translates to:
  /// **'Personalized help and explanations'**
  String get consentAiBody;

  /// No description provided for @consentVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice recording'**
  String get consentVoice;

  /// No description provided for @consentVoiceBody.
  ///
  /// In en, this message translates to:
  /// **'For reading practice; audio is deleted within 30 days'**
  String get consentVoiceBody;

  /// No description provided for @consentChangeLater.
  ///
  /// In en, this message translates to:
  /// **'You can change these anytime in the Parent Zone.'**
  String get consentChangeLater;

  /// No description provided for @agreeContinue.
  ///
  /// In en, this message translates to:
  /// **'Agree & continue'**
  String get agreeContinue;

  /// No description provided for @setPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a parent PIN'**
  String get setPinTitle;

  /// No description provided for @setPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This keeps settings and the Parent Zone for grown-ups only.'**
  String get setPinSubtitle;

  /// No description provided for @parentPin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get parentPin;

  /// No description provided for @confirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get confirmPin;

  /// No description provided for @pinTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 4 digits'**
  String get pinTooShort;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get pinMismatch;

  /// No description provided for @enterPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Grown-ups only'**
  String get enterPinTitle;

  /// No description provided for @enterPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your parent PIN to continue.'**
  String get enterPinSubtitle;

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN, try again'**
  String get wrongPin;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @loggedInPin.
  ///
  /// In en, this message translates to:
  /// **'You\'re signed in'**
  String get loggedInPin;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get passwordHint;

  /// No description provided for @usePinInstead.
  ///
  /// In en, this message translates to:
  /// **'No account? Use a PIN'**
  String get usePinInstead;

  /// No description provided for @createAccountInstead.
  ///
  /// In en, this message translates to:
  /// **'Create an account instead'**
  String get createAccountInstead;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get invalidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @wrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password, try again'**
  String get wrongPassword;

  /// No description provided for @parentAccount.
  ///
  /// In en, this message translates to:
  /// **'Parent account'**
  String get parentAccount;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @createAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'So you can manage settings and save your child\'s progress.'**
  String get createAccountSubtitle;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String signedInAs(String email);

  /// No description provided for @createChildTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your child'**
  String get createChildTitle;

  /// No description provided for @createChildSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a fun name and an animal buddy to learn with!'**
  String get createChildSubtitle;

  /// No description provided for @childNickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get childNickname;

  /// No description provided for @childNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'What should we call them?'**
  String get childNicknameHint;

  /// No description provided for @chooseAvatar.
  ///
  /// In en, this message translates to:
  /// **'Choose an animal'**
  String get chooseAvatar;

  /// No description provided for @childAge.
  ///
  /// In en, this message translates to:
  /// **'Age {age} ({band})'**
  String childAge(int age, String band);

  /// No description provided for @whoIsLearning.
  ///
  /// In en, this message translates to:
  /// **'Who is learning?'**
  String get whoIsLearning;

  /// No description provided for @addChild.
  ///
  /// In en, this message translates to:
  /// **'Add child'**
  String get addChild;

  /// No description provided for @parentZone.
  ///
  /// In en, this message translates to:
  /// **'Parent Zone'**
  String get parentZone;

  /// No description provided for @children.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get children;

  /// No description provided for @ageBandLabel.
  ///
  /// In en, this message translates to:
  /// **'Ages {band}'**
  String ageBandLabel(String band);

  /// No description provided for @lessonsDone.
  ///
  /// In en, this message translates to:
  /// **'{count} lessons'**
  String lessonsDone(int count);

  /// No description provided for @privacyData.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get privacyData;

  /// No description provided for @switchChild.
  ///
  /// In en, this message translates to:
  /// **'Switch child'**
  String get switchChild;

  /// No description provided for @lockParentZone.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lockParentZone;

  /// No description provided for @storybooks.
  ///
  /// In en, this message translates to:
  /// **'Storybooks'**
  String get storybooks;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @theEnd.
  ///
  /// In en, this message translates to:
  /// **'The End!'**
  String get theEnd;

  /// No description provided for @readAgain.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get readAgain;

  /// No description provided for @curriculum.
  ///
  /// In en, this message translates to:
  /// **'Curriculum'**
  String get curriculum;

  /// No description provided for @forGrownups.
  ///
  /// In en, this message translates to:
  /// **'For grown-ups'**
  String get forGrownups;

  /// No description provided for @grownupCheck.
  ///
  /// In en, this message translates to:
  /// **'Grown-up check'**
  String get grownupCheck;

  /// No description provided for @grownupCheckBody.
  ///
  /// In en, this message translates to:
  /// **'Ask a grown-up to continue. Type these numbers:'**
  String get grownupCheckBody;

  /// No description provided for @gateAnswerHint.
  ///
  /// In en, this message translates to:
  /// **'Type the answer'**
  String get gateAnswerHint;

  /// No description provided for @wrongNumbers.
  ///
  /// In en, this message translates to:
  /// **'Those numbers don\'t match — try again'**
  String get wrongNumbers;

  /// No description provided for @stageOf.
  ///
  /// In en, this message translates to:
  /// **'Stage {stage} · Ages {ages}'**
  String stageOf(int stage, String ages);

  /// No description provided for @legalSection.
  ///
  /// In en, this message translates to:
  /// **'About & legal'**
  String get legalSection;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @legalDraftNote.
  ///
  /// In en, this message translates to:
  /// **'Draft — pending legal review'**
  String get legalDraftNote;

  /// No description provided for @levelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String levelLabel(int level);

  /// No description provided for @streakLabel.
  ///
  /// In en, this message translates to:
  /// **'{days}-day streak'**
  String streakLabel(int days);

  /// No description provided for @accessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get accessibility;

  /// No description provided for @textSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get textSizeSmall;

  /// No description provided for @textSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get textSizeMedium;

  /// No description provided for @textSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get textSizeLarge;

  /// No description provided for @readAloud.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get readAloud;

  /// No description provided for @readAloudBody.
  ///
  /// In en, this message translates to:
  /// **'Speak instructions and narration'**
  String get readAloudBody;

  /// No description provided for @achievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievements;

  /// No description provided for @noBadgesYet.
  ///
  /// In en, this message translates to:
  /// **'Play to earn badges!'**
  String get noBadgesYet;

  /// No description provided for @comingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'More coming soon!'**
  String get comingSoonTitle;

  /// No description provided for @comingSoonBody.
  ///
  /// In en, this message translates to:
  /// **'New activities for this subject are on the way.'**
  String get comingSoonBody;

  /// No description provided for @tapToPlay.
  ///
  /// In en, this message translates to:
  /// **'Tap to play!'**
  String get tapToPlay;

  /// No description provided for @tapEachPrompt.
  ///
  /// In en, this message translates to:
  /// **'Tap them all!'**
  String get tapEachPrompt;

  /// No description provided for @dragToBasket.
  ///
  /// In en, this message translates to:
  /// **'Drag it into the basket!'**
  String get dragToBasket;

  /// No description provided for @badgeFirstLesson.
  ///
  /// In en, this message translates to:
  /// **'First lesson'**
  String get badgeFirstLesson;

  /// No description provided for @badgeFiveLessons.
  ///
  /// In en, this message translates to:
  /// **'5 lessons'**
  String get badgeFiveLessons;

  /// No description provided for @badgeStreak3.
  ///
  /// In en, this message translates to:
  /// **'3-day streak'**
  String get badgeStreak3;

  /// No description provided for @badgeStreak7.
  ///
  /// In en, this message translates to:
  /// **'7-day streak'**
  String get badgeStreak7;

  /// No description provided for @badgeFirstStory.
  ///
  /// In en, this message translates to:
  /// **'First story'**
  String get badgeFirstStory;

  /// No description provided for @badgeLevel5.
  ///
  /// In en, this message translates to:
  /// **'Level 5'**
  String get badgeLevel5;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
