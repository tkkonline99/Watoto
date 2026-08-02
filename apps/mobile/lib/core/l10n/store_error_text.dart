import '../../l10n/gen/app_localizations.dart';
import '../offline/store_error.dart';

/// Says a [StoreError] in the family's language.
///
/// The store names the cause and stays out of the language business (see
/// `store_error.dart`); this is the one place that turns a cause into words.
/// [fallback] covers anything that is not a [StoreError] — a bug, a Hive
/// failure — where the honest answer is the screen's generic "could not do
/// that" rather than a raw exception dumped at a parent.
String storeErrorText(
  AppLocalizations l10n,
  Object error, {
  required String fallback,
}) {
  if (error is! StoreError) return fallback;
  return switch (error.code) {
    StoreErrorCode.passwordTooShort => l10n.passwordTooShort,
    StoreErrorCode.noAccountForEmail => l10n.noAccountForEmail,
    StoreErrorCode.invalidResetRequest => l10n.noAccountForEmail,
    StoreErrorCode.invalidResetCode => l10n.passwordResetCodeInvalid,
    StoreErrorCode.resetCodeExpired => l10n.resetCodeExpired,
    StoreErrorCode.wrongPassword => l10n.wrongPassword,
    StoreErrorCode.pinFormat => l10n.pinTooShort,
    StoreErrorCode.childNotFound => fallback,
    StoreErrorCode.nicknameRequired => l10n.nicknameRequired,
    StoreErrorCode.nicknameCooldown => l10n.nicknameCooldown(error.days ?? 0),
  };
}
