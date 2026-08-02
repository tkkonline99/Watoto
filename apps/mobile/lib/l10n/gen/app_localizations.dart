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

  /// No description provided for @enterPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to continue.'**
  String get enterPasswordSubtitle;

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

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get welcomeBack;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to carry on.'**
  String get loginSubtitle;

  /// No description provided for @usePinToLogIn.
  ///
  /// In en, this message translates to:
  /// **'Use your PIN instead'**
  String get usePinToLogIn;

  /// No description provided for @usePasswordToLogIn.
  ///
  /// In en, this message translates to:
  /// **'Use your password instead'**
  String get usePasswordToLogIn;

  /// No description provided for @noCredentialsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'There is no password or PIN saved on this device. Set a new PIN to carry on.'**
  String get noCredentialsSubtitle;

  /// No description provided for @pinLockedFor.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait {seconds}s.'**
  String pinLockedFor(int seconds);

  /// No description provided for @myAccount.
  ///
  /// In en, this message translates to:
  /// **'My account'**
  String get myAccount;

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Your information'**
  String get personalInfo;

  /// No description provided for @signInMethod.
  ///
  /// In en, this message translates to:
  /// **'How you sign in'**
  String get signInMethod;

  /// No description provided for @signInMethodPassword.
  ///
  /// In en, this message translates to:
  /// **'Email & password'**
  String get signInMethodPassword;

  /// No description provided for @signInMethodPin.
  ///
  /// In en, this message translates to:
  /// **'Parent PIN'**
  String get signInMethodPin;

  /// No description provided for @noEmailSaved.
  ///
  /// In en, this message translates to:
  /// **'No email saved'**
  String get noEmailSaved;

  /// No description provided for @consentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Consent given'**
  String get consentRecorded;

  /// No description provided for @noChildrenYet.
  ///
  /// In en, this message translates to:
  /// **'No children added yet'**
  String get noChildrenYet;

  /// No description provided for @childNameAge.
  ///
  /// In en, this message translates to:
  /// **'{name}, age {age}'**
  String childNameAge(String name, int age);

  /// No description provided for @consentEnabled.
  ///
  /// In en, this message translates to:
  /// **'What you turned on'**
  String get consentEnabled;

  /// No description provided for @consentProgressOnly.
  ///
  /// In en, this message translates to:
  /// **'Progress saving only'**
  String get consentProgressOnly;

  /// No description provided for @childProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get childProfileLabel;

  /// No description provided for @yourPlan.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get yourPlan;

  /// No description provided for @planPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium · every stage'**
  String get planPremium;

  /// No description provided for @planFreeAll.
  ///
  /// In en, this message translates to:
  /// **'Free · every stage'**
  String get planFreeAll;

  /// No description provided for @planFreeUpTo.
  ///
  /// In en, this message translates to:
  /// **'Free · stages 1–{max}'**
  String planFreeUpTo(int max);

  /// No description provided for @yourData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get yourData;

  /// No description provided for @whereItIsSaved.
  ///
  /// In en, this message translates to:
  /// **'Where it\'s saved'**
  String get whereItIsSaved;

  /// No description provided for @dataOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'On this device only'**
  String get dataOnThisDevice;

  /// No description provided for @syncStatus.
  ///
  /// In en, this message translates to:
  /// **'Progress backup'**
  String get syncStatus;

  /// No description provided for @dataAllSaved.
  ///
  /// In en, this message translates to:
  /// **'Everything is saved'**
  String get dataAllSaved;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPasswordLabel;

  /// No description provided for @currentPinLabel.
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get currentPinLabel;

  /// No description provided for @wrongCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'That password is not right'**
  String get wrongCurrentPassword;

  /// No description provided for @wrongCurrentPin.
  ///
  /// In en, this message translates to:
  /// **'That PIN is not right'**
  String get wrongCurrentPin;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChanged;

  /// No description provided for @pinChanged.
  ///
  /// In en, this message translates to:
  /// **'PIN changed'**
  String get pinChanged;

  /// No description provided for @addEmail.
  ///
  /// In en, this message translates to:
  /// **'Add an email'**
  String get addEmail;

  /// No description provided for @addEmailBody.
  ///
  /// In en, this message translates to:
  /// **'So you can get back in if you forget your PIN'**
  String get addEmailBody;

  /// No description provided for @emailSaved.
  ///
  /// In en, this message translates to:
  /// **'Email saved'**
  String get emailSaved;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Removes your account, your children and all their progress from this device.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'This erases your account, your children\'s profiles and everything they have learned on this device. It cannot be undone. Continue?'**
  String get deleteAccountConfirm;

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
  /// **'Those numbers don\'t match. Try again'**
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

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get gotIt;

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

  /// No description provided for @keepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going!'**
  String get keepGoing;

  /// No description provided for @curriculumGuides.
  ///
  /// In en, this message translates to:
  /// **'Curriculum Guides'**
  String get curriculumGuides;

  /// No description provided for @curriculumGuidesBody.
  ///
  /// In en, this message translates to:
  /// **'Lesson plans, worksheets & reading guides for grown-ups'**
  String get curriculumGuidesBody;

  /// No description provided for @curriculumGuidesIntro.
  ///
  /// In en, this message translates to:
  /// **'The full teaching program behind Watoto\'s activities — lesson plans, printable worksheets, quizzes with answer keys, and reading guides, organized by age.'**
  String get curriculumGuidesIntro;

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

  /// No description provided for @badgeDailyChallenge.
  ///
  /// In en, this message translates to:
  /// **'Daily hero'**
  String get badgeDailyChallenge;

  /// No description provided for @badgesTitle.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badgesTitle;

  /// No description provided for @xpToNextLevel.
  ///
  /// In en, this message translates to:
  /// **'{into} / {total} XP · {remaining} to next level'**
  String xpToNextLevel(int into, int total, int remaining);

  /// No description provided for @dailyChallengeDone.
  ///
  /// In en, this message translates to:
  /// **'Done for today!'**
  String get dailyChallengeDone;

  /// No description provided for @dailyChallengeBonus.
  ///
  /// In en, this message translates to:
  /// **'+{xp} bonus XP'**
  String dailyChallengeBonus(int xp);

  /// No description provided for @changeAgeHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press to change age'**
  String get changeAgeHint;

  /// No description provided for @playNow.
  ///
  /// In en, this message translates to:
  /// **'Play now'**
  String get playNow;

  /// No description provided for @continueLearning.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get continueLearning;

  /// No description provided for @avatarShop.
  ///
  /// In en, this message translates to:
  /// **'Avatar shop'**
  String get avatarShop;

  /// No description provided for @avatarShopBody.
  ///
  /// In en, this message translates to:
  /// **'Spend coins on fun animal friends. Coins never buy learning, only looks!'**
  String get avatarShopBody;

  /// No description provided for @freeAvatars.
  ///
  /// In en, this message translates to:
  /// **'Your animals'**
  String get freeAvatars;

  /// No description provided for @shopAvatars.
  ///
  /// In en, this message translates to:
  /// **'Unlock more'**
  String get shopAvatars;

  /// No description provided for @notEnoughCoins.
  ///
  /// In en, this message translates to:
  /// **'Need more coins. Play to earn!'**
  String get notEnoughCoins;

  /// No description provided for @screenTime.
  ///
  /// In en, this message translates to:
  /// **'Screen time'**
  String get screenTime;

  /// No description provided for @screenTimeBody.
  ///
  /// In en, this message translates to:
  /// **'Soft daily limit. When time is up, Watoto shows a rest screen (no hard lock-outs mid-activity).'**
  String get screenTimeBody;

  /// No description provided for @screenTimeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get screenTimeOff;

  /// No description provided for @screenTimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String screenTimeMinutes(int minutes);

  /// No description provided for @screenTimeUsed.
  ///
  /// In en, this message translates to:
  /// **'Used today: {minutes} min'**
  String screenTimeUsed(int minutes);

  /// No description provided for @restTitle.
  ///
  /// In en, this message translates to:
  /// **'Time for a rest!'**
  String get restTitle;

  /// No description provided for @restBody.
  ///
  /// In en, this message translates to:
  /// **'You learned a lot today. Stretch, drink water, and come back later.'**
  String get restBody;

  /// No description provided for @restGoHome.
  ///
  /// In en, this message translates to:
  /// **'See you later'**
  String get restGoHome;

  /// No description provided for @restAskGrownUp.
  ///
  /// In en, this message translates to:
  /// **'Grown-up: open parent zone'**
  String get restAskGrownUp;

  /// No description provided for @restGrace.
  ///
  /// In en, this message translates to:
  /// **'+10 more minutes'**
  String get restGrace;

  /// No description provided for @premiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Watoto Premium'**
  String get premiumTitle;

  /// No description provided for @premiumBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock every stage, offline packs, and full multi-child access.'**
  String get premiumBody;

  /// No description provided for @premiumBullet1.
  ///
  /// In en, this message translates to:
  /// **'All stages Birth–Grade 4'**
  String get premiumBullet1;

  /// No description provided for @premiumBullet2.
  ///
  /// In en, this message translates to:
  /// **'Offline downloads'**
  String get premiumBullet2;

  /// No description provided for @premiumBullet3.
  ///
  /// In en, this message translates to:
  /// **'Up to 4 child profiles'**
  String get premiumBullet3;

  /// No description provided for @premiumMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly (sandbox)'**
  String get premiumMonthly;

  /// No description provided for @premiumAnnual.
  ///
  /// In en, this message translates to:
  /// **'Annual (sandbox)'**
  String get premiumAnnual;

  /// No description provided for @premiumActive.
  ///
  /// In en, this message translates to:
  /// **'Premium is on for this device'**
  String get premiumActive;

  /// No description provided for @premiumSandboxNote.
  ///
  /// In en, this message translates to:
  /// **'Sandbox mode grants local Premium until store products are connected. Real IAP uses Apple/Google only (parent zone).'**
  String get premiumSandboxNote;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @restoreNone.
  ///
  /// In en, this message translates to:
  /// **'No purchases to restore yet.'**
  String get restoreNone;

  /// No description provided for @premiumAskGrownUp.
  ///
  /// In en, this message translates to:
  /// **'Ask a grown-up to unlock Premium'**
  String get premiumAskGrownUp;

  /// No description provided for @tourTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s play together!'**
  String get tourTitle;

  /// No description provided for @tourBody.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}! Try one short activity with me. I\'ll cheer you on.'**
  String tourBody(String name);

  /// No description provided for @tourStart.
  ///
  /// In en, this message translates to:
  /// **'Start first lesson'**
  String get tourStart;

  /// No description provided for @tourSkip.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get tourSkip;

  /// No description provided for @badgeUnlocked.
  ///
  /// In en, this message translates to:
  /// **'New badge!'**
  String get badgeUnlocked;

  /// No description provided for @levelUp.
  ///
  /// In en, this message translates to:
  /// **'Level {level}! Amazing!'**
  String levelUp(int level);

  /// No description provided for @quizHint.
  ///
  /// In en, this message translates to:
  /// **'Need a hint?'**
  String get quizHint;

  /// No description provided for @quizHintBody.
  ///
  /// In en, this message translates to:
  /// **'Look carefully… one choice is gone. You\'ve got this!'**
  String get quizHintBody;

  /// No description provided for @quizNiceTry.
  ///
  /// In en, this message translates to:
  /// **'Yes! You figured it out!'**
  String get quizNiceTry;

  /// No description provided for @quizPerfect.
  ///
  /// In en, this message translates to:
  /// **'Perfect score!'**
  String get quizPerfect;

  /// No description provided for @weeklySnapshot.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get weeklySnapshot;

  /// No description provided for @weeklySnapshotEmpty.
  ///
  /// In en, this message translates to:
  /// **'No activity yet this week — a short lesson is a great start.'**
  String get weeklySnapshotEmpty;

  /// No description provided for @weeklySnapshotBody.
  ///
  /// In en, this message translates to:
  /// **'{lessons} lessons · {stars} quiz stars · {days} active days'**
  String weeklySnapshotBody(int lessons, int stars, int days);

  /// No description provided for @weeklyActivities.
  ///
  /// In en, this message translates to:
  /// **'activities'**
  String get weeklyActivities;

  /// No description provided for @parentInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get parentInsights;

  /// No description provided for @parentInsightsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add a child profile to see weekly insights.'**
  String get parentInsightsEmpty;

  /// No description provided for @certificateTitle.
  ///
  /// In en, this message translates to:
  /// **'Certificate'**
  String get certificateTitle;

  /// No description provided for @certificateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Celebrate progress with a shareable certificate'**
  String get certificateSubtitle;

  /// No description provided for @certificateHeading.
  ///
  /// In en, this message translates to:
  /// **'CERTIFICATE OF LEARNING'**
  String get certificateHeading;

  /// No description provided for @certificateNeedChild.
  ///
  /// In en, this message translates to:
  /// **'Select a child profile first.'**
  String get certificateNeedChild;

  /// No description provided for @certificateBody.
  ///
  /// In en, this message translates to:
  /// **'Reached level {level} · {lessons} lessons · {stars} stars'**
  String certificateBody(int level, int lessons, int stars);

  /// No description provided for @readingEase.
  ///
  /// In en, this message translates to:
  /// **'Reading ease'**
  String get readingEase;

  /// No description provided for @readingEaseBody.
  ///
  /// In en, this message translates to:
  /// **'Wider letter spacing and line height for easier reading'**
  String get readingEaseBody;

  /// No description provided for @highContrast.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get highContrast;

  /// No description provided for @highContrastBody.
  ///
  /// In en, this message translates to:
  /// **'Stronger colors and borders for low vision'**
  String get highContrastBody;

  /// No description provided for @reducedMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get reducedMotion;

  /// No description provided for @reducedMotionBody.
  ///
  /// In en, this message translates to:
  /// **'Calmer animations and mascot movement'**
  String get reducedMotionBody;

  /// No description provided for @analyticsOptIn.
  ///
  /// In en, this message translates to:
  /// **'Help improve Watoto'**
  String get analyticsOptIn;

  /// No description provided for @analyticsOptInBody.
  ///
  /// In en, this message translates to:
  /// **'Optional, privacy-preserving product analytics (no ads, no child free text)'**
  String get analyticsOptInBody;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export family data'**
  String get exportData;

  /// No description provided for @exportDataBody.
  ///
  /// In en, this message translates to:
  /// **'Copy a JSON summary of local progress to the clipboard'**
  String get exportDataBody;

  /// No description provided for @exportDataCopied.
  ///
  /// In en, this message translates to:
  /// **'Data copied to clipboard'**
  String get exportDataCopied;

  /// No description provided for @deleteChild.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}'**
  String deleteChild(String name);

  /// No description provided for @deleteChildBody.
  ///
  /// In en, this message translates to:
  /// **'Removes this profile and their progress on this device'**
  String get deleteChildBody;

  /// No description provided for @deleteChildConfirm.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone on this device. Continue?'**
  String get deleteChildConfirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'{count} items waiting to sync'**
  String syncPending(int count);

  /// No description provided for @premiumMapFree.
  ///
  /// In en, this message translates to:
  /// **'Free includes stages 1–5. Premium unlocks stages 6–10.'**
  String get premiumMapFree;

  /// No description provided for @badgeThreeLessons.
  ///
  /// In en, this message translates to:
  /// **'3 lessons'**
  String get badgeThreeLessons;

  /// No description provided for @badgeTenLessons.
  ///
  /// In en, this message translates to:
  /// **'10 lessons'**
  String get badgeTenLessons;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @editNicknameTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get editNicknameTitle;

  /// No description provided for @editNicknameBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a new name for this profile.'**
  String get editNicknameBody;

  /// No description provided for @nicknameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Name updated'**
  String get nicknameUpdated;

  /// No description provided for @nicknameUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the name'**
  String get nicknameUpdateFailed;

  /// No description provided for @nicknameCooldown.
  ///
  /// In en, this message translates to:
  /// **'You can change this name again in {days} days'**
  String nicknameCooldown(int days);

  /// No description provided for @insightQuietWeek.
  ///
  /// In en, this message translates to:
  /// **'A quiet week'**
  String get insightQuietWeek;

  /// No description provided for @insightQuietWeekDetail.
  ///
  /// In en, this message translates to:
  /// **'{name} has not played this week. A short story is a gentle way back in.'**
  String insightQuietWeekDetail(String name);

  /// No description provided for @insightStrongWeek.
  ///
  /// In en, this message translates to:
  /// **'A strong week'**
  String get insightStrongWeek;

  /// No description provided for @insightStrongWeekDetail.
  ///
  /// In en, this message translates to:
  /// **'{name} finished {count} lessons this week. Tell them you noticed!'**
  String insightStrongWeekDetail(String name, int count);

  /// No description provided for @insightStreak.
  ///
  /// In en, this message translates to:
  /// **'{days}-day streak'**
  String insightStreak(int days);

  /// No description provided for @insightStreakDetail.
  ///
  /// In en, this message translates to:
  /// **'Showing up daily is the habit that matters most.'**
  String get insightStreakDetail;

  /// No description provided for @insightStars.
  ///
  /// In en, this message translates to:
  /// **'Stars are adding up'**
  String get insightStars;

  /// No description provided for @insightStarsDetail.
  ///
  /// In en, this message translates to:
  /// **'{count} stars earned this week.'**
  String insightStarsDetail(int count);

  /// No description provided for @insightOneDay.
  ///
  /// In en, this message translates to:
  /// **'One day of play'**
  String get insightOneDay;

  /// No description provided for @insightOneDayDetail.
  ///
  /// In en, this message translates to:
  /// **'Two or three short sessions a week beat one long one.'**
  String get insightOneDayDetail;

  /// No description provided for @syncStatusOk.
  ///
  /// In en, this message translates to:
  /// **'Everything is saved'**
  String get syncStatusOk;

  /// No description provided for @syncStatusPending.
  ///
  /// In en, this message translates to:
  /// **'{count} items waiting to sync'**
  String syncStatusPending(int count);

  /// No description provided for @syncStatusError.
  ///
  /// In en, this message translates to:
  /// **'Sync paused — it will retry automatically'**
  String get syncStatusError;

  /// No description provided for @parentGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Grown-ups only'**
  String get parentGateTitle;

  /// No description provided for @parentGateBody.
  ///
  /// In en, this message translates to:
  /// **'To continue, answer: {question}'**
  String parentGateBody(String question);

  /// No description provided for @parentGateWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite. Try again'**
  String get parentGateWrong;

  /// No description provided for @forgotPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot your PIN?'**
  String get forgotPinTitle;

  /// No description provided for @forgotPinBodyAccount.
  ///
  /// In en, this message translates to:
  /// **'Enter your account password to set a new PIN.'**
  String get forgotPinBodyAccount;

  /// No description provided for @forgotPinBodyPinOnly.
  ///
  /// In en, this message translates to:
  /// **'This family uses a PIN only, so there is no password to check. Set a new PIN below.'**
  String get forgotPinBodyPinOnly;

  /// No description provided for @newPinLabel.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get newPinLabel;

  /// No description provided for @confirmPinLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new PIN'**
  String get confirmPinLabel;

  /// No description provided for @pinLengthHint.
  ///
  /// In en, this message translates to:
  /// **'Use at least 4 digits'**
  String get pinLengthHint;

  /// No description provided for @setNewPin.
  ///
  /// In en, this message translates to:
  /// **'Set new PIN'**
  String get setNewPin;

  /// No description provided for @pinResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'PIN updated'**
  String get pinResetSuccess;

  /// No description provided for @pinResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the PIN'**
  String get pinResetFailed;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we will send you a reset code.'**
  String get forgotPasswordBody;

  /// No description provided for @forgotPasswordEnterCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the code we sent, then choose a new password.'**
  String get forgotPasswordEnterCodeBody;

  /// No description provided for @sendResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Send reset code'**
  String get sendResetEmail;

  /// No description provided for @resendResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Send the code again'**
  String get resendResetEmail;

  /// No description provided for @passwordResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Check your email for the reset code.'**
  String get passwordResetEmailSent;

  /// No description provided for @passwordResetDevCode.
  ///
  /// In en, this message translates to:
  /// **'Debug code: {code}'**
  String passwordResetDevCode(String code);

  /// No description provided for @passwordResetCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset code'**
  String get passwordResetCodeLabel;

  /// No description provided for @passwordResetCodeHint.
  ///
  /// In en, this message translates to:
  /// **'The 6-digit code from your email'**
  String get passwordResetCodeHint;

  /// No description provided for @passwordResetCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code is not right — check your email'**
  String get passwordResetCodeInvalid;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordMismatch;

  /// No description provided for @setNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get setNewPassword;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get passwordResetSuccess;

  /// No description provided for @passwordResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reset the password'**
  String get passwordResetFailed;

  /// No description provided for @todayQuest.
  ///
  /// In en, this message translates to:
  /// **'Today\'s quest'**
  String get todayQuest;

  /// No description provided for @todayQuestProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {goal} activities'**
  String todayQuestProgress(int done, int goal);

  /// No description provided for @todayQuestComplete.
  ///
  /// In en, this message translates to:
  /// **'Quest complete!'**
  String get todayQuestComplete;

  /// No description provided for @nextEasier.
  ///
  /// In en, this message translates to:
  /// **'A gentle one next'**
  String get nextEasier;

  /// No description provided for @nextHarder.
  ///
  /// In en, this message translates to:
  /// **'Ready for a tougher one?'**
  String get nextHarder;

  /// No description provided for @nextDiscover.
  ///
  /// In en, this message translates to:
  /// **'Try something new'**
  String get nextDiscover;

  /// No description provided for @streakSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your streak is safe!'**
  String get streakSavedTitle;

  /// No description provided for @streakSavedBody.
  ///
  /// In en, this message translates to:
  /// **'You missed a day, so your weekly shield kept the {days}-day streak going.'**
  String streakSavedBody(int days);

  /// No description provided for @streakShieldUsedNote.
  ///
  /// In en, this message translates to:
  /// **'Shield used this week'**
  String get streakShieldUsedNote;

  /// No description provided for @coinsEarned.
  ///
  /// In en, this message translates to:
  /// **'+{count} coins'**
  String coinsEarned(int count);

  /// No description provided for @perfectRun.
  ///
  /// In en, this message translates to:
  /// **'Perfect!'**
  String get perfectRun;

  /// No description provided for @firstTimeHere.
  ///
  /// In en, this message translates to:
  /// **'Your first one here!'**
  String get firstTimeHere;

  /// No description provided for @remindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice reminders'**
  String get remindersTitle;

  /// No description provided for @remindersBody.
  ///
  /// In en, this message translates to:
  /// **'A quiet nudge to you — never to your child. Off unless you turn it on.'**
  String get remindersBody;

  /// No description provided for @remindersUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Reminders are not available on this device.'**
  String get remindersUnsupported;

  /// No description provided for @remindersDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked. Allow them in system settings to use reminders.'**
  String get remindersDenied;

  /// No description provided for @reminderTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminderTimeLabel;

  /// No description provided for @reminderStreakTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s streak ends today'**
  String reminderStreakTitle(String name);

  /// No description provided for @reminderStreakBody.
  ///
  /// In en, this message translates to:
  /// **'One short activity keeps the {days}-day run alive.'**
  String reminderStreakBody(int days);

  /// No description provided for @reminderInactiveTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} hasn\'t played in a while'**
  String reminderInactiveTitle(String name);

  /// No description provided for @reminderInactiveBody.
  ///
  /// In en, this message translates to:
  /// **'A short story is a gentle way back in.'**
  String get reminderInactiveBody;

  /// No description provided for @reminderKeepGoingTitle.
  ///
  /// In en, this message translates to:
  /// **'Time to play with {name}?'**
  String reminderKeepGoingTitle(String name);

  /// No description provided for @reminderKeepGoingBody.
  ///
  /// In en, this message translates to:
  /// **'Five minutes today is worth more than an hour on Sunday.'**
  String get reminderKeepGoingBody;

  /// No description provided for @shopDecorations.
  ///
  /// In en, this message translates to:
  /// **'Savanna decorations'**
  String get shopDecorations;

  /// No description provided for @shopDecorationsBody.
  ///
  /// In en, this message translates to:
  /// **'Spend coins to grow your savanna. Some things arrive just by playing.'**
  String get shopDecorationsBody;

  /// No description provided for @decorationOwned.
  ///
  /// In en, this message translates to:
  /// **'In your savanna'**
  String get decorationOwned;

  /// No description provided for @decorationEarned.
  ///
  /// In en, this message translates to:
  /// **'Earned!'**
  String get decorationEarned;

  /// No description provided for @decorationNeedsLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String decorationNeedsLevel(int level);

  /// No description provided for @decorationNeedsSubjects.
  ///
  /// In en, this message translates to:
  /// **'{count} subjects'**
  String decorationNeedsSubjects(int count);

  /// No description provided for @nameYourFriend.
  ///
  /// In en, this message translates to:
  /// **'Name your friend'**
  String get nameYourFriend;

  /// No description provided for @mascotNameHint.
  ///
  /// In en, this message translates to:
  /// **'What shall we call them?'**
  String get mascotNameHint;

  /// No description provided for @mascotDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Your lion friend'**
  String get mascotDefaultName;

  /// No description provided for @mascotMissedYou.
  ///
  /// In en, this message translates to:
  /// **'I missed you! Shall we play?'**
  String get mascotMissedYou;

  /// No description provided for @mascotProud.
  ///
  /// In en, this message translates to:
  /// **'{days} days in a row. I\'m so proud!'**
  String mascotProud(int days);

  /// No description provided for @mascotCurious.
  ///
  /// In en, this message translates to:
  /// **'There you are! What shall we learn?'**
  String get mascotCurious;

  /// No description provided for @mascotReady.
  ///
  /// In en, this message translates to:
  /// **'Ready when you are!'**
  String get mascotReady;

  /// No description provided for @familyChallenge.
  ///
  /// In en, this message translates to:
  /// **'Family challenge'**
  String get familyChallenge;

  /// No description provided for @familyChallengeBody.
  ///
  /// In en, this message translates to:
  /// **'{count} more activities together this week.'**
  String familyChallengeBody(int count);

  /// No description provided for @familyChallengeDone.
  ///
  /// In en, this message translates to:
  /// **'Done. The whole family got there!'**
  String get familyChallengeDone;

  /// No description provided for @sendCheer.
  ///
  /// In en, this message translates to:
  /// **'Send {name} a cheer'**
  String sendCheer(String name);

  /// No description provided for @sendCheerBody.
  ///
  /// In en, this message translates to:
  /// **'They will see it next time they open the app.'**
  String get sendCheerBody;

  /// No description provided for @cheerSent.
  ///
  /// In en, this message translates to:
  /// **'Sent to {name}'**
  String cheerSent(String name);

  /// No description provided for @cheerFromGrownUp.
  ///
  /// In en, this message translates to:
  /// **'A message for you'**
  String get cheerFromGrownUp;

  /// No description provided for @cheerProud.
  ///
  /// In en, this message translates to:
  /// **'I\'m proud of you!'**
  String get cheerProud;

  /// No description provided for @cheerWow.
  ///
  /// In en, this message translates to:
  /// **'Wow, look at you go!'**
  String get cheerWow;

  /// No description provided for @cheerKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going, you\'ve got this!'**
  String get cheerKeepGoing;

  /// No description provided for @cheerLoveIt.
  ///
  /// In en, this message translates to:
  /// **'I love learning with you!'**
  String get cheerLoveIt;

  /// No description provided for @certificateSave.
  ///
  /// In en, this message translates to:
  /// **'Save picture'**
  String get certificateSave;

  /// No description provided for @certificateSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get certificateSaving;

  /// No description provided for @certificateSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String certificateSaved(String path);

  /// No description provided for @certificateCopied.
  ///
  /// In en, this message translates to:
  /// **'Certificate copied to the clipboard'**
  String get certificateCopied;

  /// No description provided for @certificateSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the certificate'**
  String get certificateSaveFailed;

  /// No description provided for @recapTitle.
  ///
  /// In en, this message translates to:
  /// **'What did we learn?'**
  String get recapTitle;

  /// No description provided for @recapProgress.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String recapProgress(int current, int total);

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get restoreBackup;

  /// No description provided for @restoreBackupBody.
  ///
  /// In en, this message translates to:
  /// **'Bring progress back after a reinstall or on a new device'**
  String get restoreBackupBody;

  /// No description provided for @restoreBackupPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste the backup text you saved'**
  String get restoreBackupPaste;

  /// No description provided for @restoreBackupAction.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreBackupAction;

  /// No description provided for @restoreBackupDone.
  ///
  /// In en, this message translates to:
  /// **'Restored {children} profile(s) and {items} activities'**
  String restoreBackupDone(int children, int items);

  /// No description provided for @restoreBackupNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing new to restore — this device is already up to date'**
  String get restoreBackupNothing;

  /// No description provided for @restoreBackupInvalid.
  ///
  /// In en, this message translates to:
  /// **'That does not look like a Watoto backup'**
  String get restoreBackupInvalid;

  /// No description provided for @backupReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep a backup'**
  String get backupReminderTitle;

  /// No description provided for @backupReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Progress lives on this device only. Export a backup so a lost or reset phone does not lose it.'**
  String get backupReminderBody;

  /// No description provided for @narrationUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice not available'**
  String get narrationUnavailableTitle;

  /// No description provided for @narrationUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'This device has no installed voice for {language}. Captions still show every word. To add a voice, open your device settings and install {language} text-to-speech.'**
  String narrationUnavailableBody(String language);

  /// No description provided for @nextReview.
  ///
  /// In en, this message translates to:
  /// **'Let\'s practice this one again'**
  String get nextReview;

  /// No description provided for @badgeTwentyLessons.
  ///
  /// In en, this message translates to:
  /// **'20 lessons'**
  String get badgeTwentyLessons;

  /// No description provided for @badgeStreak14.
  ///
  /// In en, this message translates to:
  /// **'14-day streak'**
  String get badgeStreak14;

  /// No description provided for @badgeThreeStories.
  ///
  /// In en, this message translates to:
  /// **'3 stories'**
  String get badgeThreeStories;

  /// No description provided for @badgeLevel10.
  ///
  /// In en, this message translates to:
  /// **'Level 10'**
  String get badgeLevel10;

  /// No description provided for @badgeFirstQuiz.
  ///
  /// In en, this message translates to:
  /// **'First quiz'**
  String get badgeFirstQuiz;

  /// No description provided for @badgePerfectQuiz.
  ///
  /// In en, this message translates to:
  /// **'All correct!'**
  String get badgePerfectQuiz;

  /// No description provided for @highFiveTitle.
  ///
  /// In en, this message translates to:
  /// **'High five!'**
  String get highFiveTitle;

  /// No description provided for @highFiveBody.
  ///
  /// In en, this message translates to:
  /// **'{name}, that\'s your first activity today. Well done!'**
  String highFiveBody(String name);

  /// No description provided for @highFiveGrownUp.
  ///
  /// In en, this message translates to:
  /// **'Grown-ups: a short daily habit beats a long weekly one.'**
  String get highFiveGrownUp;

  /// No description provided for @highFiveButton.
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get highFiveButton;

  /// No description provided for @stretchTitle.
  ///
  /// In en, this message translates to:
  /// **'Wiggle break!'**
  String get stretchTitle;

  /// No description provided for @stretchBody.
  ///
  /// In en, this message translates to:
  /// **'You have been learning for a while. Stand up, stretch tall, and shake your hands.'**
  String get stretchBody;

  /// No description provided for @stretchKeepPlaying.
  ///
  /// In en, this message translates to:
  /// **'I stretched. Keep playing'**
  String get stretchKeepPlaying;

  /// No description provided for @stretchGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get stretchGoHome;

  /// No description provided for @whatsNewTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get whatsNewTitle;

  /// No description provided for @whatsNewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You are on version {version}'**
  String whatsNewSubtitle(String version);

  /// No description provided for @whatsNewFooter.
  ///
  /// In en, this message translates to:
  /// **'Watoto works offline. Progress stays on this device unless you export a backup.'**
  String get whatsNewFooter;

  /// No description provided for @yesShort.
  ///
  /// In en, this message translates to:
  /// **'Yes!'**
  String get yesShort;

  /// No description provided for @levelUpShort.
  ///
  /// In en, this message translates to:
  /// **'Level up!'**
  String get levelUpShort;

  /// No description provided for @codeTapBlocks.
  ///
  /// In en, this message translates to:
  /// **'Tap blocks in order!'**
  String get codeTapBlocks;

  /// No description provided for @codeReadyRun.
  ///
  /// In en, this message translates to:
  /// **'Ready — smash RUN!'**
  String get codeReadyRun;

  /// No description provided for @codeRunning.
  ///
  /// In en, this message translates to:
  /// **'Running…'**
  String get codeRunning;

  /// No description provided for @codeItWorked.
  ///
  /// In en, this message translates to:
  /// **'It worked!'**
  String get codeItWorked;

  /// No description provided for @codeYourName.
  ///
  /// In en, this message translates to:
  /// **'1. Your name'**
  String get codeYourName;

  /// No description provided for @codeYourAge.
  ///
  /// In en, this message translates to:
  /// **'2. Your age: {age}'**
  String codeYourAge(int age);

  /// No description provided for @codeWillPrint.
  ///
  /// In en, this message translates to:
  /// **'Will print:'**
  String get codeWillPrint;

  /// No description provided for @codeWhatShouldItSay.
  ///
  /// In en, this message translates to:
  /// **'What should it say?'**
  String get codeWhatShouldItSay;

  /// No description provided for @codeWhatGoesInBox.
  ///
  /// In en, this message translates to:
  /// **'What goes in the box?'**
  String get codeWhatGoesInBox;

  /// No description provided for @codeRepeatTimes.
  ///
  /// In en, this message translates to:
  /// **'Repeat {count} times'**
  String codeRepeatTimes(int count);

  /// No description provided for @codeDropBlocks.
  ///
  /// In en, this message translates to:
  /// **'⬇ drop blocks here'**
  String get codeDropBlocks;

  /// No description provided for @codeOutput.
  ///
  /// In en, this message translates to:
  /// **'OUTPUT'**
  String get codeOutput;

  /// No description provided for @codeRun.
  ///
  /// In en, this message translates to:
  /// **'RUN'**
  String get codeRun;

  /// No description provided for @codeMadeItTalk.
  ///
  /// In en, this message translates to:
  /// **'⭐ You made the computer talk! ⭐'**
  String get codeMadeItTalk;
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
