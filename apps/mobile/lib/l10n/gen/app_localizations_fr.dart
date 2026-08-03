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
  String get enterPasswordSubtitle => 'Saisis ton mot de passe pour continuer.';

  @override
  String get wrongPin => 'Code incorrect, réessaie';

  @override
  String get unlock => 'Déverrouiller';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get logIn => 'Se connecter';

  @override
  String get logOut => 'Se déconnecter';

  @override
  String get loggedInPin => 'Tu es connecté';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get emailHint => 'toi@exemple.com';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get passwordHint => 'Au moins 6 caractères';

  @override
  String get usePinInstead => 'Pas de compte ? Utilise un code';

  @override
  String get createAccountInstead => 'Ou crée un compte';

  @override
  String get invalidEmail => 'Entre un e-mail valide';

  @override
  String get passwordTooShort => 'Utilise au moins 6 caractères';

  @override
  String get wrongPassword => 'Mot de passe incorrect, réessaie';

  @override
  String get parentAccount => 'Compte parent';

  @override
  String get account => 'Compte';

  @override
  String get createAccountSubtitle =>
      'Pour gérer les réglages et sauvegarder les progrès de ton enfant.';

  @override
  String signedInAs(String email) {
    return 'Connecté en tant que $email';
  }

  @override
  String get welcomeBack => 'Bon retour !';

  @override
  String get loginSubtitle => 'Saisis ton mot de passe pour continuer.';

  @override
  String get usePinToLogIn => 'Utiliser ton code à la place';

  @override
  String get usePasswordToLogIn => 'Utiliser ton mot de passe à la place';

  @override
  String get noCredentialsSubtitle =>
      'Aucun mot de passe ni code n\'est enregistré sur cet appareil. Choisis un nouveau code pour continuer.';

  @override
  String pinLockedFor(int seconds) {
    return 'Trop d\'essais. Attends $seconds s.';
  }

  @override
  String get myAccount => 'Mon compte';

  @override
  String get personalInfo => 'Tes informations';

  @override
  String get signInMethod => 'Ta façon de te connecter';

  @override
  String get signInMethodPassword => 'E-mail et mot de passe';

  @override
  String get signInMethodPin => 'Code parent';

  @override
  String get noEmailSaved => 'Aucun e-mail enregistré';

  @override
  String get consentRecorded => 'Consentement donné';

  @override
  String get noChildrenYet => 'Aucun enfant ajouté pour l\'instant';

  @override
  String childNameAge(String name, int age) {
    return '$name, $age ans';
  }

  @override
  String get consentEnabled => 'Ce que tu as activé';

  @override
  String get consentProgressOnly => 'Sauvegarde des progrès uniquement';

  @override
  String get childProfileLabel => 'Enfant';

  @override
  String get yourPlan => 'Ta formule';

  @override
  String get planPremium => 'Premium · toutes les étapes';

  @override
  String get planFreeAll => 'Gratuit · toutes les étapes';

  @override
  String planFreeUpTo(int max) {
    return 'Gratuit · étapes 1–$max';
  }

  @override
  String get yourData => 'Tes données';

  @override
  String get whereItIsSaved => 'Où c\'est enregistré';

  @override
  String get dataOnThisDevice => 'Sur cet appareil uniquement';

  @override
  String get syncStatus => 'Sauvegarde des progrès';

  @override
  String get dataAllSaved => 'Tout est enregistré';

  @override
  String get changePassword => 'Changer le mot de passe';

  @override
  String get changePin => 'Changer le code';

  @override
  String get currentPasswordLabel => 'Mot de passe actuel';

  @override
  String get currentPinLabel => 'Code actuel';

  @override
  String get wrongCurrentPassword => 'Ce mot de passe n\'est pas le bon';

  @override
  String get wrongCurrentPin => 'Ce code n\'est pas le bon';

  @override
  String get passwordChanged => 'Mot de passe changé';

  @override
  String get pinChanged => 'Code changé';

  @override
  String get addEmail => 'Ajouter un e-mail';

  @override
  String get addEmailBody => 'Pour revenir si tu oublies ton code';

  @override
  String get emailSaved => 'E-mail enregistré';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteAccountBody =>
      'Supprime ton compte, tes enfants et tous leurs progrès de cet appareil.';

  @override
  String get deleteAccountConfirm =>
      'Cela efface ton compte, les profils de tes enfants et tout ce qu\'ils ont appris sur cet appareil. C\'est irréversible. Continuer ?';

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
  String get wrongNumbers => 'Ces chiffres ne correspondent pas. Réessaie';

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

  @override
  String levelLabel(int level) {
    return 'Niveau $level';
  }

  @override
  String streakLabel(int days) {
    return 'Série de $days jours';
  }

  @override
  String get accessibility => 'Accessibilité';

  @override
  String get textSizeSmall => 'Petit';

  @override
  String get textSizeMedium => 'Moyen';

  @override
  String get textSizeLarge => 'Grand';

  @override
  String get readAloud => 'Lecture à voix haute';

  @override
  String get readAloudBody => 'Énoncer les consignes et la narration';

  @override
  String get achievements => 'Réalisations';

  @override
  String get noBadgesYet => 'Joue pour gagner des badges !';

  @override
  String get comingSoonTitle => 'Bientôt plus !';

  @override
  String get comingSoonBody =>
      'De nouvelles activités arrivent pour cette matière.';

  @override
  String get tapToPlay => 'Touche pour jouer !';

  @override
  String get gotIt => 'Compris !';

  @override
  String get tapEachPrompt => 'Touche-les tous !';

  @override
  String get dragToBasket => 'Glisse-le dans le panier !';

  @override
  String get keepGoing => 'On continue !';

  @override
  String get curriculumGuides => 'Guides pédagogiques';

  @override
  String get curriculumGuidesBody =>
      'Plans de leçons, fiches et guides de lecture pour les adultes';

  @override
  String get curriculumGuidesIntro =>
      'Le programme complet derrière les activités de Watoto — plans de leçons, fiches imprimables, quiz avec corrigés et guides de lecture, classés par âge.';

  @override
  String get badgeFirstLesson => 'Première leçon';

  @override
  String get badgeFiveLessons => '5 leçons';

  @override
  String get badgeStreak3 => 'Série de 3 jours';

  @override
  String get badgeStreak7 => 'Série de 7 jours';

  @override
  String get badgeFirstStory => 'Première histoire';

  @override
  String get badgeLevel5 => 'Niveau 5';

  @override
  String get badgeDailyChallenge => 'Héros du jour';

  @override
  String get badgesTitle => 'Badges';

  @override
  String xpToNextLevel(int into, int total, int remaining) {
    return '$into / $total XP · $remaining jusqu\'au prochain niveau';
  }

  @override
  String get dailyChallengeDone => 'Terminé pour aujourd\'hui !';

  @override
  String dailyChallengeBonus(int xp) {
    return '+$xp XP bonus';
  }

  @override
  String get changeAgeHint => 'Appui long pour changer l\'âge';

  @override
  String get playNow => 'Jouer';

  @override
  String get continueLearning => 'Continuer';

  @override
  String get avatarShop => 'Boutique d\'avatars';

  @override
  String get avatarShopBody =>
      'Dépense des pièces pour de nouveaux animaux. Les pièces n\'achètent jamais d\'apprentissage, seulement le look !';

  @override
  String get freeAvatars => 'Tes animaux';

  @override
  String get shopAvatars => 'En débloquer plus';

  @override
  String get notEnoughCoins => 'Il faut plus de pièces. Joue pour en gagner !';

  @override
  String get screenTime => 'Temps d\'écran';

  @override
  String get screenTimeBody =>
      'Limite douce par jour. Quand c\'est fini, Watoto propose une pause (jamais au milieu d\'une activité).';

  @override
  String get screenTimeOff => 'Off';

  @override
  String screenTimeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String screenTimeUsed(int minutes) {
    return 'Aujourd\'hui : $minutes min';
  }

  @override
  String get restTitle => 'C\'est l\'heure de se reposer !';

  @override
  String get restBody =>
      'Tu as bien appris aujourd\'hui. Étire-toi, bois de l\'eau, et reviens plus tard.';

  @override
  String get restGoHome => 'À plus tard';

  @override
  String get restAskGrownUp => 'Adulte : zone parent';

  @override
  String get restGrace => '+10 minutes';

  @override
  String get premiumTitle => 'Watoto Premium';

  @override
  String get premiumBody =>
      'Débloque tous les niveaux, le hors-ligne et plusieurs profils.';

  @override
  String get premiumBullet1 => 'Tous les niveaux, de la naissance au CE1';

  @override
  String get premiumBullet2 => 'Téléchargements hors-ligne';

  @override
  String get premiumBullet3 => 'Jusqu\'à 4 profils enfants';

  @override
  String get premiumMonthly => 'Mensuel (sandbox)';

  @override
  String get premiumAnnual => 'Annuel (sandbox)';

  @override
  String get premiumActive => 'Premium est actif sur cet appareil';

  @override
  String get premiumSandboxNote =>
      'Le mode sandbox active Premium localement jusqu\'à la connexion des boutiques.';

  @override
  String get restorePurchases => 'Restaurer les achats';

  @override
  String get restoreNone => 'Aucun achat à restaurer.';

  @override
  String get premiumAskGrownUp => 'Demande à un adulte de débloquer Premium';

  @override
  String get tourTitle => 'On joue ensemble !';

  @override
  String tourBody(String name) {
    return 'Salut $name ! Faisons une petite activité. Je t\'encourage.';
  }

  @override
  String get tourStart => 'Première leçon';

  @override
  String get tourSkip => 'Plus tard';

  @override
  String get badgeUnlocked => 'Nouveau badge !';

  @override
  String levelUp(int level) {
    return 'Niveau $level ! Bravo !';
  }

  @override
  String get quizHint => 'Un indice ?';

  @override
  String get quizHintBody =>
      'Regarde bien… un choix a disparu. Tu peux le faire !';

  @override
  String get quizNiceTry => 'Oui ! Tu as trouvé !';

  @override
  String get quizPerfect => 'Score parfait !';

  @override
  String get weeklySnapshot => 'Cette semaine';

  @override
  String get weeklySnapshotEmpty =>
      'Pas encore d\'activité cette semaine — une courte leçon est un super début.';

  @override
  String weeklySnapshotBody(int lessons, int stars, int days) {
    return '$lessons leçons · $stars étoiles · $days jours actifs';
  }

  @override
  String get weeklyActivities => 'activités';

  @override
  String get parentInsights => 'Apercus';

  @override
  String get parentInsightsEmpty =>
      'Ajoutez un profil enfant pour voir les apercus.';

  @override
  String get certificateTitle => 'Certificat';

  @override
  String get certificateSubtitle => 'Celebrez les progres avec un certificat';

  @override
  String get certificateHeading => 'CERTIFICAT D APPRENTISSAGE';

  @override
  String get certificateNeedChild => 'Choisissez d abord un profil enfant.';

  @override
  String certificateBody(int level, int lessons, int stars) {
    return 'Niveau $level - $lessons lecons - $stars etoiles';
  }

  @override
  String get readingEase => 'Lecture facilitee';

  @override
  String get readingEaseBody =>
      'Espacement plus large pour une lecture plus aisee';

  @override
  String get highContrast => 'Contraste eleve';

  @override
  String get highContrastBody => 'Couleurs et bordures plus fortes';

  @override
  String get reducedMotion => 'Moins de mouvement';

  @override
  String get reducedMotionBody => 'Animations plus calmes';

  @override
  String get analyticsOptIn => 'Ameliorer Watoto';

  @override
  String get analyticsOptInBody => 'Statistiques produit optionnelles';

  @override
  String get exportData => 'Exporter les donnees';

  @override
  String get exportDataBody => 'Copier un resume JSON des progres locaux';

  @override
  String get exportDataCopied => 'Donnees copiees';

  @override
  String deleteChild(String name) {
    return 'Supprimer $name';
  }

  @override
  String get deleteChildBody =>
      'Supprime ce profil et ses progres sur cet appareil';

  @override
  String get deleteChildConfirm => 'Action irreversible. Continuer?';

  @override
  String get delete => 'Supprimer';

  @override
  String get cancel => 'Annuler';

  @override
  String syncPending(int count) {
    return '$count elements en attente de sync';
  }

  @override
  String get premiumMapFree => 'Gratuit: etapes 1-5. Premium: etapes 6-10.';

  @override
  String get badgeThreeLessons => '3 leçons';

  @override
  String get badgeTenLessons => '10 leçons';

  @override
  String get save => 'Enregistrer';

  @override
  String get editNicknameTitle => 'Modifier le nom';

  @override
  String get editNicknameBody => 'Choisissez un nouveau nom pour ce profil.';

  @override
  String get nicknameUpdated => 'Nom mis à jour';

  @override
  String get nicknameUpdateFailed => 'Impossible de mettre à jour le nom';

  @override
  String nicknameCooldown(int days) {
    return 'Vous pourrez changer ce nom dans $days jours';
  }

  @override
  String get insightQuietWeek => 'Une semaine calme';

  @override
  String insightQuietWeekDetail(String name) {
    return '$name n\'a pas joué cette semaine. Une courte histoire est une façon douce de reprendre.';
  }

  @override
  String get insightStrongWeek => 'Une belle semaine';

  @override
  String insightStrongWeekDetail(String name, int count) {
    return '$name a terminé $count leçons cette semaine. Dites-lui que vous l\'avez remarqué !';
  }

  @override
  String insightStreak(int days) {
    return 'Série de $days jours';
  }

  @override
  String get insightStreakDetail =>
      'Venir chaque jour est l\'habitude qui compte le plus.';

  @override
  String get insightStars => 'Les étoiles s\'accumulent';

  @override
  String insightStarsDetail(int count) {
    return '$count étoiles gagnées cette semaine.';
  }

  @override
  String get insightOneDay => 'Un jour de jeu';

  @override
  String get insightOneDayDetail =>
      'Deux ou trois courtes séances par semaine valent mieux qu\'une longue.';

  @override
  String get syncStatusOk => 'Tout est enregistré';

  @override
  String syncStatusPending(int count) {
    return '$count éléments en attente de synchronisation';
  }

  @override
  String get syncStatusError =>
      'Synchronisation en pause — nouvelle tentative automatique';

  @override
  String get parentGateTitle => 'Adultes uniquement';

  @override
  String parentGateBody(String question) {
    return 'Pour continuer, répondez : $question';
  }

  @override
  String get parentGateWrong => 'Pas tout à fait. Réessayez';

  @override
  String get forgotPinTitle => 'Code PIN oublié ?';

  @override
  String get forgotPinBodyAccount =>
      'Saisissez le mot de passe de votre compte pour définir un nouveau code PIN.';

  @override
  String get forgotPinBodyPinOnly =>
      'Cette famille utilise uniquement un code PIN, il n\'y a donc pas de mot de passe à vérifier. Définissez un nouveau code PIN ci-dessous.';

  @override
  String get newPinLabel => 'Nouveau code PIN';

  @override
  String get confirmPinLabel => 'Confirmez le nouveau code PIN';

  @override
  String get pinLengthHint => 'Utilisez au moins 4 chiffres';

  @override
  String get setNewPin => 'Définir le nouveau code PIN';

  @override
  String get pinResetSuccess => 'Code PIN mis à jour';

  @override
  String get pinResetFailed => 'Impossible de mettre à jour le code PIN';

  @override
  String get forgotPasswordTitle => 'Mot de passe oublié ?';

  @override
  String get forgotPasswordBody =>
      'Saisissez votre e-mail et nous vous enverrons un code de réinitialisation.';

  @override
  String get forgotPasswordEnterCodeBody =>
      'Saisissez le code envoyé, puis choisissez un nouveau mot de passe.';

  @override
  String get sendResetEmail => 'Envoyer le code';

  @override
  String get resendResetEmail => 'Renvoyer le code';

  @override
  String get passwordResetEmailSent =>
      'Consultez votre e-mail pour le code de réinitialisation.';

  @override
  String passwordResetDevCode(String code) {
    return 'Code de débogage : $code';
  }

  @override
  String get passwordResetCodeLabel => 'Code de réinitialisation';

  @override
  String get passwordResetCodeHint => 'Le code à 6 chiffres reçu par e-mail';

  @override
  String get passwordResetCodeInvalid =>
      'Ce code est incorrect — vérifiez votre e-mail';

  @override
  String get newPasswordLabel => 'Nouveau mot de passe';

  @override
  String get confirmPasswordLabel => 'Confirmez le nouveau mot de passe';

  @override
  String get passwordMismatch => 'Les mots de passe ne correspondent pas';

  @override
  String get setNewPassword => 'Définir le nouveau mot de passe';

  @override
  String get passwordResetSuccess => 'Mot de passe mis à jour';

  @override
  String get passwordResetFailed =>
      'Impossible de réinitialiser le mot de passe';

  @override
  String get todayQuest => 'Quête du jour';

  @override
  String todayQuestProgress(int done, int goal) {
    return '$done activités sur $goal';
  }

  @override
  String get todayQuestComplete => 'Quête terminée !';

  @override
  String get nextEasier => 'Une plus douce ensuite';

  @override
  String get nextHarder => 'Prêt pour un défi ?';

  @override
  String get nextDiscover => 'Essaie quelque chose de nouveau';

  @override
  String get streakSavedTitle => 'Ta série est sauvée !';

  @override
  String streakSavedBody(int days) {
    return 'Tu as manqué un jour : ton bouclier de la semaine a sauvé ta série de $days jours.';
  }

  @override
  String get streakShieldUsedNote => 'Bouclier utilisé cette semaine';

  @override
  String coinsEarned(int count) {
    return '+$count pièces';
  }

  @override
  String get perfectRun => 'Parfait !';

  @override
  String get firstTimeHere => 'Ta première ici !';

  @override
  String get remindersTitle => 'Rappels de pratique';

  @override
  String get remindersBody =>
      'Un rappel discret pour vous — jamais pour votre enfant. Désactivé par défaut.';

  @override
  String get remindersUnsupported =>
      'Les rappels ne sont pas disponibles sur cet appareil.';

  @override
  String get remindersDenied =>
      'Les notifications sont bloquées. Autorisez-les dans les réglages du système.';

  @override
  String get reminderTimeLabel => 'Heure du rappel';

  @override
  String reminderStreakTitle(String name) {
    return 'La série de $name se termine aujourd\'hui';
  }

  @override
  String reminderStreakBody(int days) {
    return 'Une courte activité suffit à préserver la série de $days jours.';
  }

  @override
  String reminderInactiveTitle(String name) {
    return '$name n\'a pas joué depuis un moment';
  }

  @override
  String get reminderInactiveBody =>
      'Une courte histoire est une façon douce de reprendre.';

  @override
  String reminderKeepGoingTitle(String name) {
    return 'Envie de jouer avec $name ?';
  }

  @override
  String get reminderKeepGoingBody =>
      'Cinq minutes aujourd\'hui valent mieux qu\'une heure dimanche.';

  @override
  String get shopDecorations => 'Décorations de la savane';

  @override
  String get shopDecorationsBody =>
      'Dépense des pièces pour agrandir ta savane. Certaines choses arrivent en jouant.';

  @override
  String get decorationOwned => 'Dans ta savane';

  @override
  String get decorationEarned => 'Gagné !';

  @override
  String decorationNeedsLevel(int level) {
    return 'Niveau $level';
  }

  @override
  String decorationNeedsSubjects(int count) {
    return '$count matières';
  }

  @override
  String get nameYourFriend => 'Donne un nom à ton ami';

  @override
  String get mascotNameHint => 'Comment l\'appelle-t-on ?';

  @override
  String get mascotDefaultName => 'Ton ami le lion';

  @override
  String get mascotMissedYou => 'Tu m\'as manqué ! On joue ?';

  @override
  String mascotProud(int days) {
    return '$days jours d\'affilée. Je suis fier !';
  }

  @override
  String get mascotCurious => 'Te voilà ! Qu\'apprend-on ?';

  @override
  String get mascotReady => 'Je suis prêt quand tu veux !';

  @override
  String get familyChallenge => 'Défi de la famille';

  @override
  String familyChallengeBody(int count) {
    return 'Encore $count activités ensemble cette semaine.';
  }

  @override
  String get familyChallengeDone => 'Réussi. Toute la famille y est arrivée !';

  @override
  String sendCheer(String name) {
    return 'Envoyer un encouragement à $name';
  }

  @override
  String get sendCheerBody =>
      'Il ou elle le verra à la prochaine ouverture de l\'application.';

  @override
  String cheerSent(String name) {
    return 'Envoyé à $name';
  }

  @override
  String get cheerFromGrownUp => 'Un message pour toi';

  @override
  String get cheerProud => 'Je suis fier de toi !';

  @override
  String get cheerWow => 'Waouh, quel progrès !';

  @override
  String get cheerKeepGoing => 'Continue, tu vas y arriver !';

  @override
  String get cheerLoveIt => 'J\'adore apprendre avec toi !';

  @override
  String get certificateSave => 'Enregistrer l\'image';

  @override
  String get certificateSaving => 'Enregistrement…';

  @override
  String certificateSaved(String path) {
    return 'Enregistré dans $path';
  }

  @override
  String get certificateCopied => 'Certificat copié dans le presse-papiers';

  @override
  String get certificateSaveFailed => 'Impossible d\'enregistrer le certificat';

  @override
  String get recapTitle => 'Qu\'avons-nous appris ?';

  @override
  String recapProgress(int current, int total) {
    return 'Question $current sur $total';
  }

  @override
  String get restoreBackup => 'Restaurer depuis une sauvegarde';

  @override
  String get restoreBackupBody =>
      'Récupérer la progression après une réinstallation ou sur un nouvel appareil';

  @override
  String get restoreBackupPaste =>
      'Collez le texte de sauvegarde que vous avez enregistré';

  @override
  String get restoreBackupAction => 'Restaurer';

  @override
  String restoreBackupDone(int children, int items) {
    return '$children profil(s) et $items activités restaurés';
  }

  @override
  String get restoreBackupNothing =>
      'Rien de nouveau à restaurer — cet appareil est déjà à jour';

  @override
  String get restoreBackupInvalid =>
      'Ceci ne ressemble pas à une sauvegarde Watoto';

  @override
  String get backupReminderTitle => 'Gardez une sauvegarde';

  @override
  String get backupReminderBody =>
      'La progression n\'existe que sur cet appareil. Exportez une sauvegarde pour ne pas la perdre si le téléphone est perdu ou réinitialisé.';

  @override
  String get narrationUnavailableTitle => 'Voix indisponible';

  @override
  String narrationUnavailableBody(String language) {
    return 'Cet appareil n\'a pas de voix installée pour $language. Les sous-titres affichent toujours chaque mot. Pour ajouter une voix, ouvrez les paramètres de votre appareil et installez la synthèse vocale $language.';
  }

  @override
  String get nextReview => 'On refait celui-là ensemble';

  @override
  String get badgeTwentyLessons => '20 leçons';

  @override
  String get badgeStreak14 => 'Série de 14 jours';

  @override
  String get badgeThreeStories => '3 histoires';

  @override
  String get badgeLevel10 => 'Niveau 10';

  @override
  String get badgeFirstQuiz => 'Premier quiz';

  @override
  String get badgePerfectQuiz => 'Tout juste !';

  @override
  String get highFiveTitle => 'Tape m\'en cinq !';

  @override
  String highFiveBody(String name) {
    return '$name, c\'est ta première activité aujourd\'hui. Bravo !';
  }

  @override
  String get highFiveGrownUp =>
      'Pour les adultes : une courte habitude quotidienne vaut mieux qu\'une longue séance hebdomadaire.';

  @override
  String get highFiveButton => 'Continuer à jouer';

  @override
  String get stretchTitle => 'Pause étirement !';

  @override
  String get stretchBody =>
      'Tu apprends depuis un moment. Lève-toi, étire-toi bien haut et secoue les mains.';

  @override
  String get stretchKeepPlaying => 'Je me suis étiré. On continue';

  @override
  String get stretchGoHome => 'Retour à l\'accueil';

  @override
  String get whatsNewTitle => 'Nouveautés';

  @override
  String whatsNewSubtitle(String version) {
    return 'Vous utilisez la version $version';
  }

  @override
  String get whatsNewFooter =>
      'Watoto fonctionne hors ligne. La progression reste sur cet appareil, sauf si vous exportez une sauvegarde.';

  @override
  String get yesShort => 'Oui !';

  @override
  String get levelUpShort => 'Niveau supérieur !';

  @override
  String get codeTapBlocks => 'Touche les blocs dans l\'ordre !';

  @override
  String get codeReadyRun => 'Prêt — appuie sur LANCER !';

  @override
  String get codeRunning => 'Ça tourne…';

  @override
  String get codeItWorked => 'Ça marche !';

  @override
  String get codeYourName => '1. Ton prénom';

  @override
  String codeYourAge(int age) {
    return '2. Ton âge : $age';
  }

  @override
  String get codeWillPrint => 'Va afficher :';

  @override
  String get codeWhatShouldItSay => 'Qu\'est-ce qu\'il doit dire ?';

  @override
  String get codeWhatGoesInBox => 'Qu\'est-ce qui va dans la boîte ?';

  @override
  String codeRepeatTimes(int count) {
    return 'Répète $count fois';
  }

  @override
  String get codeDropBlocks => '⬇ dépose les blocs ici';

  @override
  String get codeOutput => 'RÉSULTAT';

  @override
  String get codeRun => 'LANCER';

  @override
  String get codeMadeItTalk => '⭐ Tu as fait parler l\'ordinateur ! ⭐';

  @override
  String get noAccountForEmail =>
      'Aucun compte sur cet appareil n\'utilise cette adresse';

  @override
  String get resetCodeExpired => 'Ce code a expiré — demandez-en un nouveau';

  @override
  String get nicknameRequired => 'Saisissez d\'abord un nom';

  @override
  String get mascotName => 'Kibo le lionceau';

  @override
  String get passwordResetLocalBody =>
      'Saisissez l\'adresse e-mail utilisée à l\'inscription. Votre compte est stocké sur cet appareil : Watoto affiche donc le code ici au lieu de l\'envoyer.';

  @override
  String passwordResetLocalCode(String code) {
    return 'Votre code de réinitialisation est $code';
  }

  @override
  String get passwordResetLocalWhy =>
      'Toute personne tenant cet appareil peut lire ce code — d\'où la vérification adulte au préalable. Il expire dans une heure.';

  @override
  String get passwordResetLocalCopied => 'Copié dans le presse-papiers.';

  @override
  String get passwordResetLocalEnterCodeBody =>
      'Saisissez le code affiché ci-dessus, puis choisissez un nouveau mot de passe.';

  @override
  String get passwordResetCodeHintLocal =>
      'Le code à 6 chiffres affiché ci-dessus';

  @override
  String get passwordResetKnowPin =>
      'Vous connaissez votre code PIN parent ? Vous pouvez vous connecter avec.';

  @override
  String get sendResetEmailLocal => 'Afficher mon code';

  @override
  String get resendResetEmailLocal => 'Afficher un nouveau code';
}
