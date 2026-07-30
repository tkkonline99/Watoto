import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/offline/offline_providers.dart';
import 'core/state/app_state.dart';
import 'core/theme/watoto_theme.dart';
import 'l10n/gen/app_localizations.dart';
import 'router/app_router.dart';

class WatotoApp extends ConsumerStatefulWidget {
  const WatotoApp({super.key});

  @override
  ConsumerState<WatotoApp> createState() => _WatotoAppState();
}

class _WatotoAppState extends ConsumerState<WatotoApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-lock parent zone when the app backgrounds so siblings cannot walk
    // into paywall / delete / export after a grown-up left the phone open.
    // `paused` only — not `inactive` (that fires for dialogs / app switchers
    // and would kick parents out mid-flow).
    if (state == AppLifecycleState.paused) {
      ref.read(sessionProvider.notifier).lockParent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final router = ref.watch(appRouterProvider);
    final textScale = ref.watch(textScaleProvider);
    final highContrast = ref.watch(highContrastProvider);
    final reducedMotion = ref.watch(reducedMotionProvider);
    final dyslexia = ref.watch(dyslexiaFriendlyProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildWatotoTheme(highContrast: highContrast),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final data = mq.copyWith(
          // Multiply the OS text scale by the family's chosen size so the
          // accessibility setting stacks with, rather than replaces, the
          // device's own text-scaling.
          textScaler: _ScaledTextScaler(mq.textScaler, textScale),
          // Prefer reduced motion when parent toggles it (or OS).
          disableAnimations: mq.disableAnimations || reducedMotion,
        );
        Widget tree = MediaQuery(
          data: data,
          child: _PhoneFrame(child: child!),
        );
        if (dyslexia) {
          tree = DefaultTextStyle.merge(
            style: readingEaseStyle(const TextStyle()),
            child: tree,
          );
        }
        return tree;
      },
    );
  }
}

/// Multiplies an existing [TextScaler] (usually the OS one) by a fixed factor,
/// so the in-app "Text size" control layers on top of the device setting.
class _ScaledTextScaler extends TextScaler {
  const _ScaledTextScaler(this._base, this._factor);

  final TextScaler _base;
  final double _factor;

  @override
  double scale(double fontSize) => _base.scale(fontSize) * _factor;

  @override
  double get textScaleFactor => _base.scale(1.0) * _factor;
}

/// Watoto is phone-first. On phones the app fills the screen; on wide screens
/// (web/desktop) it's centered in a phone-width column so cards and layouts
/// aren't stretched across the whole window.
///
/// Desktop gets a soft "device" chrome so the Windows window feels intentional
/// rather than a floating column on empty beige.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  static const double _maxWidth = 480;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Phone / narrow tablet: fill the screen. Wide layouts get a centered
    // phone-width column. Desktop chrome only when the window is tall enough
    // for a real desktop shell (avoids test surfaces + short windows).
    if (size.width <= 600) return child;

    final tallDesktopShell = !kIsWeb &&
        size.height >= 720 &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    final framed = tallDesktopShell
        ? Container(
            width: _maxWidth,
            height: (size.height - 40).clamp(0.0, size.height),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: WatotoColors.deep.withValues(alpha: 0.12),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: WatotoColors.deep.withValues(alpha: 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          )
        : SizedBox(width: _maxWidth, height: size.height, child: child);

    return ColoredBox(
      color: tallDesktopShell
          ? const Color(0xFFE8DFD2)
          : const Color(0xFFDED5C7),
      child: Center(child: framed),
    );
  }
}
