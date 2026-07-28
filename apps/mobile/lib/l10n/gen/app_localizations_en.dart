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
  String get homeSubtitle => 'What shall we play today?';

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
  String get createAccount => 'Create account';

  @override
  String get logIn => 'Log in';

  @override
  String get logOut => 'Log out';

  @override
  String get loggedInPin => 'You\'re signed in';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'At least 6 characters';

  @override
  String get usePinInstead => 'No account? Use a PIN';

  @override
  String get createAccountInstead => 'Create an account instead';

  @override
  String get invalidEmail => 'Enter a valid email';

  @override
  String get passwordTooShort => 'Use at least 6 characters';

  @override
  String get wrongPassword => 'Wrong password, try again';

  @override
  String get parentAccount => 'Parent account';

  @override
  String get account => 'Account';

  @override
  String get createAccountSubtitle =>
      'So you can manage settings and save your child\'s progress.';

  @override
  String signedInAs(String email) {
    return 'Signed in as $email';
  }

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

  @override
  String levelLabel(int level) {
    return 'Level $level';
  }

  @override
  String streakLabel(int days) {
    return '$days-day streak';
  }

  @override
  String get accessibility => 'Accessibility';

  @override
  String get textSizeSmall => 'Small';

  @override
  String get textSizeMedium => 'Medium';

  @override
  String get textSizeLarge => 'Large';

  @override
  String get readAloud => 'Read aloud';

  @override
  String get readAloudBody => 'Speak instructions and narration';

  @override
  String get achievements => 'Achievements';

  @override
  String get noBadgesYet => 'Play to earn badges!';

  @override
  String get comingSoonTitle => 'More coming soon!';

  @override
  String get comingSoonBody =>
      'New activities for this subject are on the way.';

  @override
  String get tapToPlay => 'Tap to play!';

  @override
  String get gotIt => 'Got it!';

  @override
  String get tapEachPrompt => 'Tap them all!';

  @override
  String get dragToBasket => 'Drag it into the basket!';

  @override
  String get keepGoing => 'Keep going!';

  @override
  String get curriculumGuides => 'Curriculum Guides';

  @override
  String get curriculumGuidesBody =>
      'Lesson plans, worksheets & reading guides for grown-ups';

  @override
  String get curriculumGuidesIntro =>
      'The full teaching program behind Watoto\'s activities — lesson plans, printable worksheets, quizzes with answer keys, and reading guides, organized by age.';

  @override
  String get badgeFirstLesson => 'First lesson';

  @override
  String get badgeFiveLessons => '5 lessons';

  @override
  String get badgeStreak3 => '3-day streak';

  @override
  String get badgeStreak7 => '7-day streak';

  @override
  String get badgeFirstStory => 'First story';

  @override
  String get badgeLevel5 => 'Level 5';

  @override
  String get badgeDailyChallenge => 'Daily hero';

  @override
  String get badgesTitle => 'Badges';

  @override
  String xpToNextLevel(int into, int total, int remaining) {
    return '$into / $total XP · $remaining to next level';
  }

  @override
  String get dailyChallengeDone => 'Done for today!';

  @override
  String dailyChallengeBonus(int xp) {
    return '+$xp bonus XP';
  }

  @override
  String get changeAgeHint => 'Long-press to change age';

  @override
  String get playNow => 'Play now';

  @override
  String get continueLearning => 'Keep going';

  @override
  String get avatarShop => 'Avatar shop';

  @override
  String get avatarShopBody =>
      'Spend coins on fun animal friends. Coins never buy learning — only looks!';

  @override
  String get freeAvatars => 'Your animals';

  @override
  String get shopAvatars => 'Unlock more';

  @override
  String get notEnoughCoins => 'Need more coins — play to earn!';

  @override
  String get screenTime => 'Screen time';

  @override
  String get screenTimeBody =>
      'Soft daily limit. When time is up, Watoto shows a rest screen (no hard lock-outs mid-activity).';

  @override
  String get screenTimeOff => 'Off';

  @override
  String screenTimeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String screenTimeUsed(int minutes) {
    return 'Used today: $minutes min';
  }

  @override
  String get restTitle => 'Time for a rest!';

  @override
  String get restBody =>
      'You learned a lot today. Stretch, drink water, and come back later.';

  @override
  String get restGoHome => 'See you later';

  @override
  String get restAskGrownUp => 'Grown-up: open parent zone';

  @override
  String get restGrace => '+10 more minutes';

  @override
  String get premiumTitle => 'Watoto Premium';

  @override
  String get premiumBody =>
      'Unlock every stage, offline packs, and full multi-child access.';

  @override
  String get premiumBullet1 => 'All stages Birth–Grade 4';

  @override
  String get premiumBullet2 => 'Offline downloads';

  @override
  String get premiumBullet3 => 'Up to 4 child profiles';

  @override
  String get premiumMonthly => 'Monthly (sandbox)';

  @override
  String get premiumAnnual => 'Annual (sandbox)';

  @override
  String get premiumActive => 'Premium is on for this device';

  @override
  String get premiumSandboxNote =>
      'Sandbox mode grants local Premium until store products are connected. Real IAP uses Apple/Google only (parent zone).';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get restoreNone => 'No purchases to restore yet.';

  @override
  String get premiumAskGrownUp => 'Ask a grown-up to unlock Premium';

  @override
  String get tourTitle => 'Let\'s play together!';

  @override
  String tourBody(String name) {
    return 'Hi $name! Try one short activity with me — I\'ll cheer you on.';
  }

  @override
  String get tourStart => 'Start first lesson';

  @override
  String get tourSkip => 'Maybe later';

  @override
  String get badgeUnlocked => 'New badge!';

  @override
  String levelUp(int level) {
    return 'Level $level! Amazing!';
  }

  @override
  String get quizHint => 'Need a hint?';

  @override
  String get quizHintBody =>
      'Look carefully… one choice is gone. You\'ve got this!';

  @override
  String get quizNiceTry => 'Yes! You figured it out!';

  @override
  String get quizPerfect => 'Perfect score!';

  @override
  String get weeklySnapshot => 'This week';

  @override
  String get weeklySnapshotEmpty =>
      'No activity yet this week — a short lesson is a great start.';

  @override
  String weeklySnapshotBody(int lessons, int stars, int days) {
    return '$lessons lessons · $stars quiz stars · $days active days';
  }

  @override
  String get weeklyActivities => 'activities';

  @override
  String get parentInsights => 'Insights';

  @override
  String get parentInsightsEmpty =>
      'Add a child profile to see weekly insights.';

  @override
  String get certificateTitle => 'Certificate';

  @override
  String get certificateSubtitle =>
      'Celebrate progress with a shareable certificate';

  @override
  String get certificateHeading => 'CERTIFICATE OF LEARNING';

  @override
  String get certificateNeedChild => 'Select a child profile first.';

  @override
  String certificateBody(int level, int lessons, int stars) {
    return 'Reached level $level · $lessons lessons · $stars stars';
  }

  @override
  String get readingEase => 'Reading ease';

  @override
  String get readingEaseBody =>
      'Wider letter spacing and line height for easier reading';

  @override
  String get highContrast => 'High contrast';

  @override
  String get highContrastBody => 'Stronger colours and borders for low vision';

  @override
  String get reducedMotion => 'Reduce motion';

  @override
  String get reducedMotionBody => 'Calmer animations and mascot movement';

  @override
  String get analyticsOptIn => 'Help improve Watoto';

  @override
  String get analyticsOptInBody =>
      'Optional, privacy-preserving product analytics (no ads, no child free text)';

  @override
  String get exportData => 'Export family data';

  @override
  String get exportDataBody =>
      'Copy a JSON summary of local progress to the clipboard';

  @override
  String get exportDataCopied => 'Data copied to clipboard';

  @override
  String deleteChild(String name) {
    return 'Delete $name';
  }

  @override
  String get deleteChildBody =>
      'Removes this profile and their progress on this device';

  @override
  String get deleteChildConfirm =>
      'This cannot be undone on this device. Continue?';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String syncPending(int count) {
    return '$count items waiting to sync';
  }

  @override
  String get premiumMapFree =>
      'Free includes stages 1–5. Premium unlocks stages 6–10.';

  @override
  String get badgeThreeLessons => '3 lessons';

  @override
  String get badgeTenLessons => '10 lessons';

  @override
  String get save => 'Save';

  @override
  String get editNicknameTitle => 'Edit name';

  @override
  String get editNicknameBody => 'Choose a new name for this profile.';

  @override
  String get nicknameUpdated => 'Name updated';

  @override
  String get nicknameUpdateFailed => 'Could not update the name';

  @override
  String nicknameCooldown(int days) {
    return 'You can change this name again in $days days';
  }

  @override
  String get insightQuietWeek => 'A quiet week';

  @override
  String insightQuietWeekDetail(String name) {
    return '$name has not played this week. A short story is a gentle way back in.';
  }

  @override
  String get insightStrongWeek => 'A strong week';

  @override
  String insightStrongWeekDetail(String name, int count) {
    return '$name finished $count lessons this week. Tell them you noticed!';
  }

  @override
  String insightStreak(int days) {
    return '$days-day streak';
  }

  @override
  String get insightStreakDetail =>
      'Showing up daily is the habit that matters most.';

  @override
  String get insightStars => 'Stars are adding up';

  @override
  String insightStarsDetail(int count) {
    return '$count stars earned this week.';
  }

  @override
  String get insightOneDay => 'One day of play';

  @override
  String get insightOneDayDetail =>
      'Two or three short sessions a week beat one long one.';

  @override
  String get syncStatusOk => 'Everything is saved';

  @override
  String syncStatusPending(int count) {
    return '$count items waiting to sync';
  }

  @override
  String get syncStatusError => 'Sync paused — it will retry automatically';

  @override
  String get parentGateTitle => 'Grown-ups only';

  @override
  String parentGateBody(String question) {
    return 'To continue, answer: $question';
  }

  @override
  String get parentGateWrong => 'Not quite — try again';

  @override
  String get forgotPinTitle => 'Forgot your PIN?';

  @override
  String get forgotPinBodyAccount =>
      'Enter your account password to set a new PIN.';

  @override
  String get forgotPinBodyPinOnly =>
      'This family uses a PIN only, so there is no password to check. Set a new PIN below.';

  @override
  String get newPinLabel => 'New PIN';

  @override
  String get confirmPinLabel => 'Confirm new PIN';

  @override
  String get pinLengthHint => 'Use at least 4 digits';

  @override
  String get setNewPin => 'Set new PIN';

  @override
  String get pinResetSuccess => 'PIN updated';

  @override
  String get pinResetFailed => 'Could not update the PIN';

  @override
  String get forgotPasswordTitle => 'Forgot your password?';

  @override
  String get forgotPasswordBody =>
      'Enter your email and we will send you a reset code.';

  @override
  String get forgotPasswordEnterCodeBody =>
      'Enter the code we sent, then choose a new password.';

  @override
  String get sendResetEmail => 'Send reset code';

  @override
  String get resendResetEmail => 'Send the code again';

  @override
  String get passwordResetEmailSent => 'Check your email for the reset code.';

  @override
  String passwordResetDevCode(String code) {
    return 'Debug code: $code';
  }

  @override
  String get passwordResetCodeLabel => 'Reset code';

  @override
  String get passwordResetCodeHint => 'The 6-digit code from your email';

  @override
  String get passwordResetCodeInvalid =>
      'That code is not right — check your email';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmPasswordLabel => 'Confirm new password';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get setNewPassword => 'Set new password';

  @override
  String get passwordResetSuccess => 'Password updated';

  @override
  String get passwordResetFailed => 'Could not reset the password';

  @override
  String get todayQuest => 'Today\'s quest';

  @override
  String todayQuestProgress(int done, int goal) {
    return '$done of $goal activities';
  }

  @override
  String get todayQuestComplete => 'Quest complete!';

  @override
  String get nextEasier => 'A gentle one next';

  @override
  String get nextHarder => 'Ready for a tougher one?';

  @override
  String get nextDiscover => 'Try something new';

  @override
  String get streakSavedTitle => 'Your streak is safe!';

  @override
  String streakSavedBody(int days) {
    return 'You missed a day, so your weekly shield kept the $days-day streak going.';
  }

  @override
  String get streakShieldUsedNote => 'Shield used this week';

  @override
  String coinsEarned(int count) {
    return '+$count coins';
  }

  @override
  String get perfectRun => 'Perfect!';

  @override
  String get firstTimeHere => 'Your first one here!';

  @override
  String get remindersTitle => 'Practice reminders';

  @override
  String get remindersBody =>
      'A quiet nudge to you — never to your child. Off unless you turn it on.';

  @override
  String get remindersUnsupported =>
      'Reminders are not available on this device.';

  @override
  String get remindersDenied =>
      'Notifications are blocked. Allow them in system settings to use reminders.';

  @override
  String get reminderTimeLabel => 'Reminder time';

  @override
  String reminderStreakTitle(String name) {
    return '$name\'s streak ends today';
  }

  @override
  String reminderStreakBody(int days) {
    return 'One short activity keeps the $days-day run alive.';
  }

  @override
  String reminderInactiveTitle(String name) {
    return '$name hasn\'t played in a while';
  }

  @override
  String get reminderInactiveBody => 'A short story is a gentle way back in.';

  @override
  String reminderKeepGoingTitle(String name) {
    return 'Time to play with $name?';
  }

  @override
  String get reminderKeepGoingBody =>
      'Five minutes today is worth more than an hour on Sunday.';

  @override
  String get shopDecorations => 'Savanna decorations';

  @override
  String get shopDecorationsBody =>
      'Spend coins to grow your savanna. Some things arrive just by playing.';

  @override
  String get decorationOwned => 'In your savanna';

  @override
  String get decorationEarned => 'Earned!';

  @override
  String decorationNeedsLevel(int level) {
    return 'Level $level';
  }

  @override
  String decorationNeedsSubjects(int count) {
    return '$count subjects';
  }

  @override
  String get nameYourFriend => 'Name your friend';

  @override
  String get mascotNameHint => 'What shall we call them?';

  @override
  String get mascotDefaultName => 'Your lion friend';

  @override
  String get mascotMissedYou => 'I missed you! Shall we play?';

  @override
  String mascotProud(int days) {
    return '$days days in a row — I\'m so proud!';
  }

  @override
  String get mascotCurious => 'There you are! What shall we learn?';

  @override
  String get mascotReady => 'Ready when you are!';

  @override
  String get familyChallenge => 'Family challenge';

  @override
  String familyChallengeBody(int count) {
    return '$count more activities together this week.';
  }

  @override
  String get familyChallengeDone => 'Done — the whole family got there!';

  @override
  String sendCheer(String name) {
    return 'Send $name a cheer';
  }

  @override
  String get sendCheerBody => 'They will see it next time they open the app.';

  @override
  String cheerSent(String name) {
    return 'Sent to $name';
  }

  @override
  String get cheerFromGrownUp => 'A message for you';

  @override
  String get cheerProud => 'I\'m proud of you!';

  @override
  String get cheerWow => 'Wow, look at you go!';

  @override
  String get cheerKeepGoing => 'Keep going, you\'ve got this!';

  @override
  String get cheerLoveIt => 'I love learning with you!';

  @override
  String get certificateSave => 'Save picture';

  @override
  String get certificateSaving => 'Saving…';

  @override
  String certificateSaved(String path) {
    return 'Saved to $path';
  }

  @override
  String get certificateCopied => 'Certificate copied to the clipboard';

  @override
  String get certificateSaveFailed => 'Could not save the certificate';
}
