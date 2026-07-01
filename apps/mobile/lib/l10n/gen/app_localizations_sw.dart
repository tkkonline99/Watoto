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
  String get wrongNumbers => 'Namba hazifanani — jaribu tena';

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
  String get tapEachPrompt => 'Zigusa zote!';

  @override
  String get dragToBasket => 'Iburute kwenye kikapu!';

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
}
