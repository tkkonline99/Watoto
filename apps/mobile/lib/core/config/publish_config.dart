/// Single source of truth for store / legal / support identity.
///
/// Override at build time with `--dart-define=KEY=value` without code edits.
/// Defaults are production-oriented for a free-only launch (no IAP).
library;

/// Legal entity name shown in privacy/terms and store forms.
const companyLegalName = String.fromEnvironment(
  'WATOTO_COMPANY_NAME',
  defaultValue: 'Watoto Learning',
);

/// Support / privacy contact email (must match the inbox you monitor).
const supportEmail = String.fromEnvironment(
  'WATOTO_SUPPORT_EMAIL',
  defaultValue: 'support@watoto.app',
);

const privacyEmail = String.fromEnvironment(
  'WATOTO_PRIVACY_EMAIL',
  defaultValue: 'privacy@watoto.app',
);

/// Public website base (host privacy + terms here for the stores).
const websiteBaseUrl = String.fromEnvironment(
  'WATOTO_WEBSITE_URL',
  defaultValue: 'https://tkkonline99.github.io/Watoto',
);

String get privacyPolicyUrl => '$websiteBaseUrl/privacy.html';
String get termsOfServiceUrl => '$websiteBaseUrl/terms.html';
String get supportUrl => '$websiteBaseUrl/support.html';

/// Android applicationId / iOS bundle id family (already wired in native projects).
const androidApplicationId = 'app.watoto.watoto_mobile';
const iosBundleId = 'app.watoto.watotoMobile';

/// When true (default), all curriculum stages unlock and the paywall is hidden.
/// Use this for a public launch **without** payments. Set
/// `--dart-define=PUBLISH_FREE_ONLY=false` once IAP is live.
const publishFreeOnly = bool.fromEnvironment(
  'PUBLISH_FREE_ONLY',
  defaultValue: true,
);

/// Effective max free stage: 10 when free-only launch, else 5.
int get effectiveFreeStageMax => publishFreeOnly ? maxPublishedStage : 5;

/// Highest curriculum stage this build offers at all.
///
/// Distinct from [effectiveFreeStageMax], which is about paying: that gates a
/// stage the build *has*. This one says the stage is not in the product.
///
/// Defaults to 10 now that all 10 stages (ages 0–10, 57 subjects, 684 items)
/// have been authored to their per-tier depth targets enforced by
/// `test/lesson_depth_test.dart` (lessons, quizzes, and stories across EN, SW,
/// and FR). Override with `--dart-define=WATOTO_MAX_STAGE=N` when testing a
/// narrower stage ceiling.
const maxPublishedStage = int.fromEnvironment(
  'WATOTO_MAX_STAGE',
  defaultValue: 10,
);

/// Policy version recorded with parental consent (keep in sync with Cloud Functions).
const consentPolicyVersionLabel = '2026-06-01';

/// Effective date for in-app legal docs.
const legalEffectiveDate = String.fromEnvironment(
  'WATOTO_LEGAL_EFFECTIVE_DATE',
  defaultValue: '2026-07-18',
);

/// Postal / registered address line for privacy policy (update before submit).
const companyAddress = String.fromEnvironment(
  'WATOTO_COMPANY_ADDRESS',
  defaultValue: 'East Africa — contact via email for formal address',
);

/// Hosting regions disclosed in privacy policy.
const dataHostingRegions = String.fromEnvironment(
  'WATOTO_DATA_REGIONS',
  defaultValue: 'on-device first; optional cloud in regions selected in Firebase (typically multi-region US/EU)',
);
