/// Screenshot / capture mode — grown-up convenience for store assets.
///
/// When enabled:
/// - Parent zone skips PIN (session unlock)
/// - Soft banner on child home (not shown mid-lesson)
/// - Optional auto demo seed
///
/// Enable via:
/// - `--dart-define=SCREENSHOT_MODE=true`
/// - Triple-tap parent lock within 1.2s on child home
library;

/// Compile-time force-on (CI / capture scripts).
const bool kScreenshotModeDefine =
    bool.fromEnvironment('SCREENSHOT_MODE', defaultValue: false);

/// Triple-tap window for the secret parent-lock gesture.
const Duration screenshotGestureWindow = Duration(milliseconds: 1200);

/// Required taps on the parent lock to enable screenshot mode.
const int screenshotGestureTaps = 3;

/// Pure gesture detector: returns true when the latest tap completes a triple.
bool registerScreenshotTap({
  required List<DateTime> tapTimes,
  required DateTime now,
  Duration window = screenshotGestureWindow,
  int requiredTaps = screenshotGestureTaps,
}) {
  tapTimes.add(now);
  // Drop taps outside the window.
  tapTimes.removeWhere((t) => now.difference(t) > window);
  return tapTimes.length >= requiredTaps;
}
