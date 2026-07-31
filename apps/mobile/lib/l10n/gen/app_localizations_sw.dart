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
  String get homeSubtitle => 'Tucheze nini leo?';

  @override
  String get startLearning => 'Anza';

  @override
  String get subjects => 'Masomo';

  @override
  String get selectAgeTitle => 'Una umri gani?';

  @override
  String get selectAgeSubtitle => 'Chagua umri ili kuona shughuli zinazofaa.';

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

  @override
  String get quizTime => 'Wakati wa jaribio!';

  @override
  String get quizCountingTitle => 'Jaribio la Kuhesabu';

  @override
  String get quizHowMany => 'Unaona ngapi?';

  @override
  String quizScore(int correct, int total) {
    return 'Umepata $correct kati ya $total!';
  }

  @override
  String get retry => 'Jaribu tena';

  @override
  String get consentTitle => 'Mahali salama pa kujifunza';

  @override
  String get consentBody =>
      'Watoto haina matangazo wala soga. Tunakusanya tu kinachohitajika kuhifadhi maendeleo ya mtoto wako. Kama mzazi, wewe huchagua kipi kiwashwe.';

  @override
  String get consentCoreData => 'Hifadhi maendeleo ya kujifunza';

  @override
  String get consentRequired => 'Inahitajika kutumia programu';

  @override
  String get consentAi => 'Mwalimu wa AI na wasaidizi';

  @override
  String get consentAiBody => 'Msaada na maelezo yaliyobinafsishwa';

  @override
  String get consentVoice => 'Kurekodi sauti';

  @override
  String get consentVoiceBody =>
      'Kwa mazoezi ya kusoma; sauti hufutwa ndani ya siku 30';

  @override
  String get consentChangeLater =>
      'Unaweza kubadilisha haya wakati wowote katika Eneo la Mzazi.';

  @override
  String get agreeContinue => 'Kubali na uendelee';

  @override
  String get setPinTitle => 'Weka PIN ya mzazi';

  @override
  String get setPinSubtitle =>
      'Hii huweka mipangilio na Eneo la Mzazi kwa watu wazima pekee.';

  @override
  String get parentPin => 'PIN';

  @override
  String get confirmPin => 'Thibitisha PIN';

  @override
  String get pinTooShort => 'Tumia angalau tarakimu 4';

  @override
  String get pinMismatch => 'PIN hazifanani';

  @override
  String get enterPinTitle => 'Watu wazima pekee';

  @override
  String get enterPinSubtitle => 'Weka PIN yako ya mzazi ili kuendelea.';

  @override
  String get wrongPin => 'PIN si sahihi, jaribu tena';

  @override
  String get unlock => 'Fungua';

  @override
  String get createAccount => 'Fungua akaunti';

  @override
  String get logIn => 'Ingia';

  @override
  String get logOut => 'Toka';

  @override
  String get loggedInPin => 'Umeingia';

  @override
  String get emailLabel => 'Barua pepe';

  @override
  String get emailHint => 'wewe@mfano.com';

  @override
  String get passwordLabel => 'Nenosiri';

  @override
  String get passwordHint => 'Angalau herufi 6';

  @override
  String get usePinInstead => 'Huna akaunti? Tumia PIN';

  @override
  String get createAccountInstead => 'Au fungua akaunti';

  @override
  String get invalidEmail => 'Weka barua pepe sahihi';

  @override
  String get passwordTooShort => 'Tumia angalau herufi 6';

  @override
  String get wrongPassword => 'Nenosiri si sahihi, jaribu tena';

  @override
  String get parentAccount => 'Akaunti ya mzazi';

  @override
  String get account => 'Akaunti';

  @override
  String get createAccountSubtitle =>
      'Ili uweze kusimamia mipangilio na kuhifadhi maendeleo ya mtoto wako.';

  @override
  String signedInAs(String email) {
    return 'Umeingia kama $email';
  }

  @override
  String get welcomeBack => 'Karibu tena!';

  @override
  String get loginSubtitle => 'Weka nenosiri lako ili kuendelea.';

  @override
  String get usePinToLogIn => 'Tumia PIN yako badala yake';

  @override
  String get usePasswordToLogIn => 'Tumia nenosiri lako badala yake';

  @override
  String get noCredentialsSubtitle =>
      'Hakuna nenosiri wala PIN iliyohifadhiwa kwenye kifaa hiki. Weka PIN mpya ili kuendelea.';

  @override
  String pinLockedFor(int seconds) {
    return 'Umejaribu mara nyingi mno. Subiri sekunde $seconds.';
  }

  @override
  String get myAccount => 'Akaunti yangu';

  @override
  String get personalInfo => 'Taarifa zako';

  @override
  String get signInMethod => 'Jinsi unavyoingia';

  @override
  String get signInMethodPassword => 'Barua pepe na nenosiri';

  @override
  String get signInMethodPin => 'PIN ya mzazi';

  @override
  String get noEmailSaved => 'Hakuna barua pepe iliyohifadhiwa';

  @override
  String get consentRecorded => 'Ridhaa ilitolewa';

  @override
  String get noChildrenYet => 'Bado hakuna mtoto aliyeongezwa';

  @override
  String childNameAge(String name, int age) {
    return '$name, miaka $age';
  }

  @override
  String get deleteAccount => 'Futa akaunti';

  @override
  String get deleteAccountBody =>
      'Huondoa akaunti yako, watoto wako na maendeleo yao yote kwenye kifaa hiki.';

  @override
  String get deleteAccountConfirm =>
      'Hii itafuta akaunti yako, wasifu wa watoto wako na kila walichojifunza kwenye kifaa hiki. Haiwezi kutenduliwa. Kuendelea?';

  @override
  String get createChildTitle => 'Ongeza mtoto wako';

  @override
  String get createChildSubtitle =>
      'Chagua jina la kufurahisha na mnyama rafiki wa kujifunza naye!';

  @override
  String get childNickname => 'Jina la utani';

  @override
  String get childNicknameHint => 'Tumwite vipi?';

  @override
  String get chooseAvatar => 'Chagua mnyama';

  @override
  String childAge(int age, String band) {
    return 'Umri $age ($band)';
  }

  @override
  String get whoIsLearning => 'Nani anajifunza?';

  @override
  String get addChild => 'Ongeza mtoto';

  @override
  String get parentZone => 'Eneo la Mzazi';

  @override
  String get children => 'Watoto';

  @override
  String ageBandLabel(String band) {
    return 'Umri $band';
  }

  @override
  String lessonsDone(int count) {
    return 'Masomo $count';
  }

  @override
  String get privacyData => 'Faragha na data';

  @override
  String get switchChild => 'Badilisha mtoto';

  @override
  String get lockParentZone => 'Funga';

  @override
  String get storybooks => 'Vitabu vya Hadithi';

  @override
  String get textSize => 'Ukubwa wa maandishi';

  @override
  String get theEnd => 'Mwisho!';

  @override
  String get readAgain => 'Soma tena';

  @override
  String get curriculum => 'Mtaala';

  @override
  String get forGrownups => 'Kwa watu wazima';

  @override
  String get grownupCheck => 'Uthibitisho wa mtu mzima';

  @override
  String get grownupCheckBody =>
      'Mwombe mtu mzima aendelee. Andika namba hizi:';

  @override
  String get gateAnswerHint => 'Andika jibu';

  @override
  String get wrongNumbers => 'Namba hazifanani. Jaribu tena';

  @override
  String stageOf(int stage, String ages) {
    return 'Hatua $stage · Umri $ages';
  }

  @override
  String get legalSection => 'Kuhusu na Kisheria';

  @override
  String get privacyPolicy => 'Sera ya Faragha';

  @override
  String get termsOfService => 'Masharti ya Huduma';

  @override
  String get legalDraftNote => 'Rasimu — inasubiri ukaguzi wa kisheria';

  @override
  String levelLabel(int level) {
    return 'Kiwango $level';
  }

  @override
  String streakLabel(int days) {
    return 'Mfululizo wa siku $days';
  }

  @override
  String get accessibility => 'Ufikivu';

  @override
  String get textSizeSmall => 'Ndogo';

  @override
  String get textSizeMedium => 'Wastani';

  @override
  String get textSizeLarge => 'Kubwa';

  @override
  String get readAloud => 'Soma kwa sauti';

  @override
  String get readAloudBody => 'Tamka maelekezo na masimulizi';

  @override
  String get achievements => 'Mafanikio';

  @override
  String get noBadgesYet => 'Cheza ili kupata beji!';

  @override
  String get comingSoonTitle => 'Mengi yanakuja hivi karibuni!';

  @override
  String get comingSoonBody => 'Shughuli mpya za somo hili zinakuja.';

  @override
  String get tapToPlay => 'Gusa ili kucheza!';

  @override
  String get gotIt => 'Nimeelewa!';

  @override
  String get tapEachPrompt => 'Zigusa zote!';

  @override
  String get dragToBasket => 'Iburute kwenye kikapu!';

  @override
  String get keepGoing => 'Endelea!';

  @override
  String get curriculumGuides => 'Miongozo ya Mtaala';

  @override
  String get curriculumGuidesBody =>
      'Mipango ya masomo, karatasi za mazoezi na miongozo ya kusoma kwa watu wazima';

  @override
  String get curriculumGuidesIntro =>
      'Programu kamili ya ufundishaji nyuma ya shughuli za Watoto — mipango ya masomo, karatasi za mazoezi, majaribio yenye majibu, na miongozo ya kusoma, kwa kila umri.';

  @override
  String get badgeFirstLesson => 'Somo la kwanza';

  @override
  String get badgeFiveLessons => 'Masomo 5';

  @override
  String get badgeStreak3 => 'Mfululizo wa siku 3';

  @override
  String get badgeStreak7 => 'Mfululizo wa siku 7';

  @override
  String get badgeFirstStory => 'Hadithi ya kwanza';

  @override
  String get badgeLevel5 => 'Kiwango 5';

  @override
  String get badgeDailyChallenge => 'Shujaa wa leo';

  @override
  String get badgesTitle => 'Beji';

  @override
  String xpToNextLevel(int into, int total, int remaining) {
    return '$into / $total XP · $remaining hadi kiwango kijacho';
  }

  @override
  String get dailyChallengeDone => 'Imekamilika leo!';

  @override
  String dailyChallengeBonus(int xp) {
    return '+$xp XP za ziada';
  }

  @override
  String get changeAgeHint => 'Bonyeza kwa muda mrefu kubadilisha umri';

  @override
  String get playNow => 'Cheza sasa';

  @override
  String get continueLearning => 'Endelea';

  @override
  String get avatarShop => 'Duka la avatar';

  @override
  String get avatarShopBody =>
      'Tumia sarafu kununua marafiki wa wanyama. Sarafu hazinunui masomo. Sura tu!';

  @override
  String get freeAvatars => 'Wanyama wako';

  @override
  String get shopAvatars => 'Fungua zaidi';

  @override
  String get notEnoughCoins => 'Unahitaji sarafu zaidi. Cheza ili upate!';

  @override
  String get screenTime => 'Muda wa skrini';

  @override
  String get screenTimeBody =>
      'Kikomo laini cha kila siku. Muda ukiisha, Watoto inaonyesha pumziko.';

  @override
  String get screenTimeOff => 'Zima';

  @override
  String screenTimeMinutes(int minutes) {
    return 'Dakika $minutes';
  }

  @override
  String screenTimeUsed(int minutes) {
    return 'Leo: dak $minutes';
  }

  @override
  String get restTitle => 'Wakati wa kupumzika!';

  @override
  String get restBody =>
      'Umejifunza mengi leo. Nyosha mwili, kunywa maji, rudi baadaye.';

  @override
  String get restGoHome => 'Tutaonana';

  @override
  String get restAskGrownUp => 'Mzazi: fungua eneo la mzazi';

  @override
  String get restGrace => '+Dakika 10';

  @override
  String get premiumTitle => 'Watoto Premium';

  @override
  String get premiumBody =>
      'Fungua hatua zote, nje ya mtandao, na wasifu wa watoto wengi.';

  @override
  String get premiumBullet1 => 'Hatua zote kutoka kuzaliwa hadi darasa la 4';

  @override
  String get premiumBullet2 => 'Vipakuliwa nje ya mtandao';

  @override
  String get premiumBullet3 => 'Wasifu wa watoto hadi 4';

  @override
  String get premiumMonthly => 'Kila mwezi (sandbox)';

  @override
  String get premiumAnnual => 'Kila mwaka (sandbox)';

  @override
  String get premiumActive => 'Premium imewashwa kwenye kifaa hiki';

  @override
  String get premiumSandboxNote =>
      'Sandbox hutoa Premium ya ndani hadi maduka yakiunganishwa.';

  @override
  String get restorePurchases => 'Rejesha ununuzi';

  @override
  String get restoreNone => 'Hakuna ununuzi wa kurejesha.';

  @override
  String get premiumAskGrownUp => 'Muulize mzazi afungue Premium';

  @override
  String get tourTitle => 'Tucheze pamoja!';

  @override
  String tourBody(String name) {
    return 'Habari $name! Tujaribu shughuli fupi. Nitakushangilia.';
  }

  @override
  String get tourStart => 'Anza somo la kwanza';

  @override
  String get tourSkip => 'Baadaye';

  @override
  String get badgeUnlocked => 'Beji mpya!';

  @override
  String levelUp(int level) {
    return 'Kiwango $level! Vizuri sana!';
  }

  @override
  String get quizHint => 'Unahitaji kidokezo?';

  @override
  String get quizHintBody =>
      'Angalia vizuri… chaguo moja limeondolewa. Unaweza!';

  @override
  String get quizNiceTry => 'Ndiyo! Umepata!';

  @override
  String get quizPerfect => 'Alama kamili!';

  @override
  String get weeklySnapshot => 'Wiki hii';

  @override
  String get weeklySnapshotEmpty =>
      'Bado hakuna shughuli wiki hii — somo fupi ni mwanzo mzuri.';

  @override
  String weeklySnapshotBody(int lessons, int stars, int days) {
    return 'Masomo $lessons · Nyota $stars · Siku $days';
  }

  @override
  String get weeklyActivities => 'shughuli';

  @override
  String get parentInsights => 'Maarifa';

  @override
  String get parentInsightsEmpty => 'Ongeza wasifu wa mtoto ili uone maarifa.';

  @override
  String get certificateTitle => 'Cheti';

  @override
  String get certificateSubtitle => 'Sherehekea maendeleo kwa cheti';

  @override
  String get certificateHeading => 'CHETI CHA KUJIFUNZA';

  @override
  String get certificateNeedChild => 'Chagua wasifu wa mtoto kwanza.';

  @override
  String certificateBody(int level, int lessons, int stars) {
    return 'Kiwango $level · Masomo $lessons · Nyota $stars';
  }

  @override
  String get readingEase => 'Urahisi wa kusoma';

  @override
  String get readingEaseBody => 'Nafasi pana za herufi na mistari';

  @override
  String get highContrast => 'Tofauti kubwa ya rangi';

  @override
  String get highContrastBody => 'Rangi na mipaka thabiti zaidi';

  @override
  String get reducedMotion => 'Punguza mwendo';

  @override
  String get reducedMotionBody => 'Uhuishaji tulivu';

  @override
  String get analyticsOptIn => 'Saidia kuboresha Watoto';

  @override
  String get analyticsOptInBody => 'Takwimu za hiari, zinazolinda faragha';

  @override
  String get exportData => 'Hamisha data';

  @override
  String get exportDataBody => 'Nakili muhtasari wa JSON wa maendeleo';

  @override
  String get exportDataCopied => 'Data imenakiliwa';

  @override
  String deleteChild(String name) {
    return 'Futa $name';
  }

  @override
  String get deleteChildBody =>
      'Inaondoa wasifu na maendeleo kwenye kifaa hiki';

  @override
  String get deleteChildConfirm =>
      'Haiwezi kurekebishwa kwenye kifaa hiki. Endelea?';

  @override
  String get delete => 'Futa';

  @override
  String get cancel => 'Ghairi';

  @override
  String syncPending(int count) {
    return 'Vipengee $count vinasubiri kusawazishwa';
  }

  @override
  String get premiumMapFree => 'Bure: hatua 1–5. Premium: hatua 6–10.';

  @override
  String get badgeThreeLessons => 'Masomo 3';

  @override
  String get badgeTenLessons => 'Masomo 10';

  @override
  String get save => 'Hifadhi';

  @override
  String get editNicknameTitle => 'Badilisha jina';

  @override
  String get editNicknameBody => 'Chagua jina jipya la wasifu huu.';

  @override
  String get nicknameUpdated => 'Jina limebadilishwa';

  @override
  String get nicknameUpdateFailed => 'Imeshindwa kubadilisha jina';

  @override
  String nicknameCooldown(int days) {
    return 'Unaweza kubadilisha jina hili tena baada ya siku $days';
  }

  @override
  String get insightQuietWeek => 'Wiki tulivu';

  @override
  String insightQuietWeekDetail(String name) {
    return '$name hajacheza wiki hii. Hadithi fupi ni njia nzuri ya kurudi.';
  }

  @override
  String get insightStrongWeek => 'Wiki nzuri';

  @override
  String insightStrongWeekDetail(String name, int count) {
    return '$name amemaliza masomo $count wiki hii. Mwambie umeona!';
  }

  @override
  String insightStreak(int days) {
    return 'Mfululizo wa siku $days';
  }

  @override
  String get insightStreakDetail =>
      'Kujifunza kila siku ndio tabia muhimu zaidi.';

  @override
  String get insightStars => 'Nyota zinaongezeka';

  @override
  String insightStarsDetail(int count) {
    return 'Nyota $count zimepatikana wiki hii.';
  }

  @override
  String get insightOneDay => 'Siku moja ya kucheza';

  @override
  String get insightOneDayDetail =>
      'Vipindi vifupi viwili au vitatu kwa wiki ni bora kuliko kimoja kirefu.';

  @override
  String get syncStatusOk => 'Kila kitu kimehifadhiwa';

  @override
  String syncStatusPending(int count) {
    return 'Vipengee $count vinasubiri kusawazishwa';
  }

  @override
  String get syncStatusError => 'Usawazishaji umesimama — utajaribu tena';

  @override
  String get parentGateTitle => 'Kwa watu wazima tu';

  @override
  String parentGateBody(String question) {
    return 'Ili kuendelea, jibu: $question';
  }

  @override
  String get parentGateWrong => 'Sio sahihi. Jaribu tena';

  @override
  String get forgotPinTitle => 'Umesahau PIN yako?';

  @override
  String get forgotPinBodyAccount =>
      'Weka nenosiri la akaunti yako ili kuweka PIN mpya.';

  @override
  String get forgotPinBodyPinOnly =>
      'Familia hii inatumia PIN pekee, hakuna nenosiri la kuthibitisha. Weka PIN mpya hapa chini.';

  @override
  String get newPinLabel => 'PIN mpya';

  @override
  String get confirmPinLabel => 'Thibitisha PIN mpya';

  @override
  String get pinLengthHint => 'Tumia angalau tarakimu 4';

  @override
  String get setNewPin => 'Weka PIN mpya';

  @override
  String get pinResetSuccess => 'PIN imebadilishwa';

  @override
  String get pinResetFailed => 'Imeshindwa kubadilisha PIN';

  @override
  String get forgotPasswordTitle => 'Umesahau nenosiri lako?';

  @override
  String get forgotPasswordBody =>
      'Weka barua pepe yako na tutakutumia msimbo wa kuweka upya.';

  @override
  String get forgotPasswordEnterCodeBody =>
      'Weka msimbo tuliokutumia, kisha chagua nenosiri jipya.';

  @override
  String get sendResetEmail => 'Tuma msimbo';

  @override
  String get resendResetEmail => 'Tuma msimbo tena';

  @override
  String get passwordResetEmailSent => 'Angalia barua pepe yako kwa msimbo.';

  @override
  String passwordResetDevCode(String code) {
    return 'Msimbo wa majaribio: $code';
  }

  @override
  String get passwordResetCodeLabel => 'Msimbo wa kuweka upya';

  @override
  String get passwordResetCodeHint =>
      'Msimbo wa tarakimu 6 kutoka barua pepe yako';

  @override
  String get passwordResetCodeInvalid =>
      'Msimbo huo si sahihi — angalia barua pepe yako';

  @override
  String get newPasswordLabel => 'Nenosiri jipya';

  @override
  String get confirmPasswordLabel => 'Thibitisha nenosiri jipya';

  @override
  String get passwordMismatch => 'Manenosiri hayalingani';

  @override
  String get setNewPassword => 'Weka nenosiri jipya';

  @override
  String get passwordResetSuccess => 'Nenosiri limebadilishwa';

  @override
  String get passwordResetFailed => 'Imeshindwa kuweka upya nenosiri';

  @override
  String get todayQuest => 'Lengo la leo';

  @override
  String todayQuestProgress(int done, int goal) {
    return 'Shughuli $done kati ya $goal';
  }

  @override
  String get todayQuestComplete => 'Lengo limefikiwa!';

  @override
  String get nextEasier => 'Rahisi kidogo sasa';

  @override
  String get nextHarder => 'Tayari kwa ngumu zaidi?';

  @override
  String get nextDiscover => 'Jaribu kitu kipya';

  @override
  String get streakSavedTitle => 'Mfululizo wako uko salama!';

  @override
  String streakSavedBody(int days) {
    return 'Ulikosa siku moja, ngao yako ya wiki ikaokoa mfululizo wa siku $days.';
  }

  @override
  String get streakShieldUsedNote => 'Ngao imetumika wiki hii';

  @override
  String coinsEarned(int count) {
    return '+Sarafu $count';
  }

  @override
  String get perfectRun => 'Kamili!';

  @override
  String get firstTimeHere => 'Yako ya kwanza hapa!';

  @override
  String get remindersTitle => 'Vikumbusho vya mazoezi';

  @override
  String get remindersBody =>
      'Kikumbusho kwako — kamwe si kwa mtoto wako. Kimezimwa hadi ukiwasha.';

  @override
  String get remindersUnsupported =>
      'Vikumbusho havipatikani kwenye kifaa hiki.';

  @override
  String get remindersDenied =>
      'Arifa zimezuiwa. Ziruhusu katika mipangilio ya mfumo ili kutumia vikumbusho.';

  @override
  String get reminderTimeLabel => 'Saa ya kikumbusho';

  @override
  String reminderStreakTitle(String name) {
    return 'Mfululizo wa $name unaisha leo';
  }

  @override
  String reminderStreakBody(int days) {
    return 'Shughuli moja fupi itaendeleza mfululizo wa siku $days.';
  }

  @override
  String reminderInactiveTitle(String name) {
    return '$name hajacheza kwa muda';
  }

  @override
  String get reminderInactiveBody => 'Hadithi fupi ni njia nzuri ya kurudi.';

  @override
  String reminderKeepGoingTitle(String name) {
    return 'Ni wakati wa kucheza na $name?';
  }

  @override
  String get reminderKeepGoingBody =>
      'Dakika tano leo ni bora kuliko saa moja Jumapili.';

  @override
  String get shopDecorations => 'Mapambo ya savana';

  @override
  String get shopDecorationsBody =>
      'Tumia sarafu kukuza savana yako. Baadhi ya vitu huja kwa kucheza tu.';

  @override
  String get decorationOwned => 'Ipo savana yako';

  @override
  String get decorationEarned => 'Umeipata!';

  @override
  String decorationNeedsLevel(int level) {
    return 'Kiwango $level';
  }

  @override
  String decorationNeedsSubjects(int count) {
    return 'Masomo $count';
  }

  @override
  String get nameYourFriend => 'Mpe rafiki yako jina';

  @override
  String get mascotNameHint => 'Tumwite nani?';

  @override
  String get mascotDefaultName => 'Rafiki yako simba';

  @override
  String get mascotMissedYou => 'Nimekukumbuka! Tucheze?';

  @override
  String mascotProud(int days) {
    return 'Siku $days mfululizo. Ninajivunia!';
  }

  @override
  String get mascotCurious => 'Umerudi! Tujifunze nini?';

  @override
  String get mascotReady => 'Niko tayari!';

  @override
  String get familyChallenge => 'Changamoto ya familia';

  @override
  String familyChallengeBody(int count) {
    return 'Shughuli $count zaidi pamoja wiki hii.';
  }

  @override
  String get familyChallengeDone => 'Imekamilika. Familia nzima imefika!';

  @override
  String sendCheer(String name) {
    return 'Mtumie $name pongezi';
  }

  @override
  String get sendCheerBody => 'Ataona mara tu atakapofungua programu.';

  @override
  String cheerSent(String name) {
    return 'Imetumwa kwa $name';
  }

  @override
  String get cheerFromGrownUp => 'Ujumbe kwa ajili yako';

  @override
  String get cheerProud => 'Ninajivunia wewe!';

  @override
  String get cheerWow => 'Vyema, unaendelea vizuri!';

  @override
  String get cheerKeepGoing => 'Endelea, unaweza!';

  @override
  String get cheerLoveIt => 'Napenda kujifunza nawe!';

  @override
  String get certificateSave => 'Hifadhi picha';

  @override
  String get certificateSaving => 'Inahifadhi…';

  @override
  String certificateSaved(String path) {
    return 'Imehifadhiwa kwenye $path';
  }

  @override
  String get certificateCopied => 'Cheti kimenakiliwa';

  @override
  String get certificateSaveFailed => 'Imeshindwa kuhifadhi cheti';

  @override
  String get recapTitle => 'Tumejifunza nini?';

  @override
  String recapProgress(int current, int total) {
    return 'Swali $current kati ya $total';
  }

  @override
  String get restoreBackup => 'Rejesha kutoka nakala rudufu';

  @override
  String get restoreBackupBody =>
      'Rudisha maendeleo baada ya kusakinisha upya au kwenye kifaa kipya';

  @override
  String get restoreBackupPaste =>
      'Bandika maandishi ya nakala rudufu uliyohifadhi';

  @override
  String get restoreBackupAction => 'Rejesha';

  @override
  String restoreBackupDone(int children, int items) {
    return 'Zimerejeshwa wasifu $children na shughuli $items';
  }

  @override
  String get restoreBackupNothing =>
      'Hakuna kipya cha kurejesha — kifaa hiki tayari kina taarifa mpya';

  @override
  String get restoreBackupInvalid =>
      'Hii haionekani kuwa nakala rudufu ya Watoto';

  @override
  String get backupReminderTitle => 'Weka nakala rudufu';

  @override
  String get backupReminderBody =>
      'Maendeleo yapo kwenye kifaa hiki pekee. Hifadhi nakala rudufu ili simu ikipotea au ikifutwa usipoteze.';

  @override
  String get narrationUnavailableTitle => 'Sauti haipatikani';

  @override
  String narrationUnavailableBody(String language) {
    return 'Kifaa hiki hakina sauti iliyosakinishwa kwa $language. Manukuu bado yanaonyesha kila neno. Ili kuongeza sauti, fungua mipangilio ya kifaa chako na usakinishe sauti ya $language.';
  }

  @override
  String get nextReview => 'Tujaribu hii tena';

  @override
  String get badgeTwentyLessons => 'Masomo 20';

  @override
  String get badgeStreak14 => 'Mfululizo wa siku 14';

  @override
  String get badgeThreeStories => 'Hadithi 3';

  @override
  String get badgeLevel10 => 'Kiwango 10';

  @override
  String get badgeFirstQuiz => 'Jaribio la kwanza';

  @override
  String get badgePerfectQuiz => 'Zote sahihi!';

  @override
  String get highFiveTitle => 'Tupige tano!';

  @override
  String highFiveBody(String name) {
    return '$name, hii ni shughuli yako ya kwanza leo. Hongera!';
  }

  @override
  String get highFiveGrownUp =>
      'Kwa wazazi: mazoezi mafupi ya kila siku ni bora kuliko marefu ya kila wiki.';

  @override
  String get highFiveButton => 'Endelea kucheza';

  @override
  String get stretchTitle => 'Mapumziko ya kujinyoosha!';

  @override
  String get stretchBody =>
      'Umekuwa ukijifunza kwa muda. Simama, jinyooshe juu, na kunja mikono yako.';

  @override
  String get stretchKeepPlaying => 'Nimejinyoosha. Endelea';

  @override
  String get stretchGoHome => 'Nenda nyumbani';

  @override
  String get whatsNewTitle => 'Mambo mapya';

  @override
  String whatsNewSubtitle(String version) {
    return 'Unatumia toleo $version';
  }

  @override
  String get whatsNewFooter =>
      'Watoto hufanya kazi bila intaneti. Maendeleo yanabaki kwenye kifaa hiki isipokuwa uhifadhi nakala rudufu.';
}
