/// Store failures a family can actually see, named by cause.
///
/// These used to be `StateError`s carrying English prose, which the parent
/// screens printed straight to the user — so a Swahili or French family
/// resetting a password read English. Worse, `pin_reset_screen` decided what
/// to show by calling `.contains('Wrong password')` on that prose, so
/// rewording the message would have silently broken the branch.
///
/// The store names the cause and stays out of the language business; the UI
/// maps the code to a string via `storeErrorText`. This file deliberately
/// imports nothing — the store layer must not reach for Flutter or l10n.
library;

enum StoreErrorCode {
  /// New password is under the minimum length.
  passwordTooShort,

  /// No account on this device matches the email given.
  noAccountForEmail,

  /// Reset asked for an email that is not the registered one.
  invalidResetRequest,

  /// Reset code does not match the stored one.
  invalidResetCode,

  /// Reset code was valid but is past its TTL.
  resetCodeExpired,

  /// Account password did not verify.
  wrongPassword,

  /// PIN is not 4–6 digits.
  pinFormat,

  /// No child profile with that id.
  childNotFound,

  /// Nickname was blank.
  nicknameRequired,

  /// Nickname was changed too recently; [StoreError.days] holds the wait.
  nicknameCooldown,
}

/// A named store failure. [days] is set only for [StoreErrorCode.nicknameCooldown].
class StoreError implements Exception {
  const StoreError(this.code, {this.days});

  final StoreErrorCode code;
  final int? days;

  @override
  String toString() =>
      'StoreError(${code.name}${days == null ? '' : ', days: $days'})';
}
