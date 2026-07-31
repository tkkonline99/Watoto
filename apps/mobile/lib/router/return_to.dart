/// Carries "where the grown-up was actually headed" through the PIN, account
/// and paywall gates.
///
/// Without it every unlock ends on the Parent Zone dashboard: a child taps a
/// locked activity, the parent enters the PIN, and the app forgets the
/// activity entirely — the family has to navigate back to it by hand. Gates
/// append `?from=<intended location>` and hand control back there once the
/// unlock succeeds.
library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Query parameter holding the post-unlock destination.
const String returnToParam = 'from';

/// `/parent/unlock` + the place the family was trying to reach.
String gateWithReturn(String gatePath, String intended) {
  if (!_isSafe(intended)) return gatePath;
  final base = Uri.parse(gatePath);
  return base.replace(
    queryParameters: {
      ...base.queryParameters,
      returnToParam: intended,
    },
  ).toString();
}

/// The location currently on screen — use it as the return target when sending
/// a grown-up off to unlock something.
String hereLocation(BuildContext context) =>
    GoRouterState.of(context).uri.toString();

/// The validated destination on the current route, or null.
String? returnTo(BuildContext context) =>
    _clean(GoRouterState.of(context).uri.queryParameters[returnToParam]);

/// The validated destination carried by [state], or null.
String? returnToOf(GoRouterState state) =>
    _clean(state.uri.queryParameters[returnToParam]);

String? _clean(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return _isSafe(raw) ? raw : null;
}

/// Only in-app locations, and never a gate itself — returning to a gate after
/// passing it would bounce the family straight back into the gate.
///
/// `/account` is deliberately *not* excluded any more: it used to be the login
/// screen, and is now an ordinary destination sitting behind the gate, so a
/// grown-up who was sent to unlock on their way there must land on it.
bool _isSafe(String location) =>
    location.startsWith('/') &&
    !location.startsWith('//') &&
    !location.startsWith('/parent/unlock') &&
    !location.startsWith('/login') &&
    !location.startsWith('/onboarding');
