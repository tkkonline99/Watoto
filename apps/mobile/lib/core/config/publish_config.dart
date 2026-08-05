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
  defaultValue: 'https://watoto.app',
);

String get privacyPolicyUrl => '$websiteBaseUrl/privacy';
String get termsOfServiceUrl => '$websiteBaseUrl/terms';
String get supportUrl => '$websiteBaseUrl/support';

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
/// Set to 7 because that is where the content stops being worth a child's
/// time. Measured against the per-tier depth in `lesson_depth_test.dart`,
/// stages 1-7 hold their lesson depth, and 6 and 7 hold it on quizzes and
/// stories too. Stages 8-10 have all 36 of their lessons below depth — two
/// steps for an eight-year-old. In playing time that is roughly two and a half
/// hours for stage 7 against about 36 minutes for stage 9.
///
/// Shipping those as "ages 8-10" would promise a band the app cannot serve,
/// to exactly the parent most likely to check. Ages 0-7 is a smaller product
/// and a true one.
///
/// It was 6 until `content/author_stage7.py` took stage 7 to depth. That is
/// the intended way to move this: author the stage, then raise the number.
/// `--dart-define=WATOTO_MAX_STAGE=10` shows the whole library in a dev build
/// without shipping it. `docs/CONTENT_WORKLIST.md` is the remaining work.
const maxPublishedStage = int.fromEnvironment(
  'WATOTO_MAX_STAGE',
  defaultValue: 9,
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
