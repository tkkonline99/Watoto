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
    return 'Bonjour, $name !';
  }

  @override
  String get dailyChallenge => 'Défi du jour';

  @override
  String get homeSubtitle => 'On joue à quoi aujourd\'hui ?';

  @override
  String get startLearning => 'Commencer';

  @override
  String get subjects => 'Matières';

  @override
  String get selectAgeTitle => 'Quel âge as-tu ?';

  @override
  String get selectAgeSubtitle =>
      'Choisis un âge pour voir les bonnes activités.';

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

  @override
  String get quizTime => 'C\'est l\'heure du quiz !';

  @override
  String get quizCountingTitle => 'Quiz de comptage';

  @override
  String get quizHowMany => 'Combien en vois-tu ?';

  @override
  String quizScore(int correct, int total) {
    return 'Tu as eu $correct sur $total !';
  }

  @override
  String get retry => 'Réessayer';

  @override
  String get consentTitle => 'Un endroit sûr pour apprendre';

  @override
  String get consentBody =>
      'Watoto n\'a ni publicité ni messagerie. Nous ne collectons que le nécessaire pour sauvegarder les progrès de votre enfant. En tant qu\'adulte, vous choisissez ce qui est activé.';

  @override
  String get consentCoreData => 'Sauvegarder les progrès';

  @override
  String get consentRequired => 'Requis pour utiliser l\'application';

  @override
  String get consentAi => 'Tuteur IA et aides';

  @override
  String get consentAiBody => 'Aide et explications personnalisées';

  @override
  String get consentVoice => 'Enregistrement vocal';

  @override
  String get consentVoiceBody =>
      'Pour la lecture ; l\'audio est supprimé sous 30 jours';

  @override
  String get consentChangeLater =>
      'Vous pouvez modifier cela à tout moment dans l\'Espace Parent.';

  @override
  String get agreeContinue => 'Accepter et continuer';

  @override
  String get setPinTitle => 'Définir un code parent';

  @override
  String get setPinSubtitle =>
      'Cela réserve les réglages et l\'Espace Parent aux adultes.';

  @override
  String get parentPin => 'Code';

  @override
  String get confirmPin => 'Confirmer le code';

  @override
  String get pinTooShort => 'Utilise au moins 4 chiffres';

  @override
  String get pinMismatch => 'Les codes ne correspondent pas';

  @override
  String get enterPinTitle => 'Adultes uniquement';

  @override
  String get enterPinSubtitle => 'Saisis ton code parent pour continuer.';

  @override
  String get wrongPin => 'Code incorrect, réessaie';

  @override
  String get unlock => 'Déverrouiller';

  @override
  String get createChildTitle => 'Ajoute ton enfant';

  @override
  String get createChildSubtitle =>
      'Choisis un nom rigolo et un animal pour apprendre avec toi !';

  @override
  String get childNickname => 'Surnom';

  @override
  String get childNicknameHint => 'Comment l\'appeler ?';

  @override
  String get chooseAvatar => 'Choisis un animal';

  @override
  String childAge(int age, String band) {
    return 'Âge $age ($band)';
  }

  @override
  String get whoIsLearning => 'Qui apprend ?';

  @override
  String get addChild => 'Ajouter un enfant';

  @override
  String get parentZone => 'Espace Parent';

  @override
  String get children => 'Enfants';

  @override
  String ageBandLabel(String band) {
    return 'Âges $band';
  }

  @override
  String lessonsDone(int count) {
    return '$count leçons';
  }

  @override
  String get privacyData => 'Confidentialité et données';

  @override
  String get switchChild => 'Changer d\'enfant';

  @override
  String get lockParentZone => 'Verrouiller';

  @override
  String get storybooks => 'Livres d\'histoires';

  @override
  String get textSize => 'Taille du texte';

  @override
  String get theEnd => 'Fin !';

  @override
  String get readAgain => 'Relire';

  @override
  String get curriculum => 'Programme';

  @override
  String get forGrownups => 'Pour les adultes';

  @override
  String get grownupCheck => 'Vérification adulte';

  @override
  String get grownupCheckBody =>
      'Demande à un adulte de continuer. Saisis ces chiffres :';

  @override
  String get gateAnswerHint => 'Tape la réponse';

  @override
  String get wrongNumbers => 'Ces chiffres ne correspondent pas — réessaie';

  @override
  String stageOf(int stage, String ages) {
    return 'Étape $stage · Âges $ages';
  }

  @override
  String get legalSection => 'À propos et mentions légales';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get termsOfService => 'Conditions d\'utilisation';

  @override
  String get legalDraftNote => 'Brouillon — en attente de révision juridique';
}
