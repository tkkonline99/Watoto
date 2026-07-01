import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/state/app_state.dart';
import 'core/theme/watoto_theme.dart';
import 'l10n/gen/app_localizations.dart';
import 'router/app_router.dart';

class WatotoApp extends ConsumerWidget {
  const WatotoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final router = ref.watch(appRouterProvider);
    final textScale = ref.watch(textScaleProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildWatotoTheme(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          // Multiply the OS text scale by the family's chosen size so the
          // accessibility setting stacks with, rather than replaces, the
          // device's own text-scaling.
          data: mq.copyWith(
            textScaler: _ScaledTextScaler(mq.textScaler, textScale),
          ),
          child: _PhoneFrame(child: child!),
        );
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
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  static const double _maxWidth = 480;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= 600) return child;
    return ColoredBox(
      color: const Color(0xFFDED5C7),
      child: Center(
        child: SizedBox(width: _maxWidth, height: size.height, child: child),
      ),
    );
  }
}
