import 'package:flutter/material.dart';

/// Savanna design tokens (docs/08-design-system.md).
abstract final class WatotoColors {
  static const sun = Color(0xFFFFB703);
  static const sky = Color(0xFF219EBC);
  static const deep = Color(0xFF023047);
  static const mango = Color(0xFFFB8500);
  static const leaf = Color(0xFF52B788);
  static const berry = Color(0xFFE76F51);
  static const cloud = Color(0xFFFDF6EC);

  // High-contrast alternates (≥7:1 on white for body text targets).
  static const hcDeep = Color(0xFF000000);
  static const hcSun = Color(0xFFE09A00);
  static const hcSky = Color(0xFF005F7A);
  static const hcCloud = Color(0xFFFFFFFF);
  static const hcBerry = Color(0xFFB00020);
}

ThemeData buildWatotoTheme({bool highContrast = false}) {
  final deep = highContrast ? WatotoColors.hcDeep : WatotoColors.deep;
  final sun = highContrast ? WatotoColors.hcSun : WatotoColors.sun;
  final sky = highContrast ? WatotoColors.hcSky : WatotoColors.sky;
  final cloud = highContrast ? WatotoColors.hcCloud : WatotoColors.cloud;
  final berry = highContrast ? WatotoColors.hcBerry : WatotoColors.berry;

  final scheme = ColorScheme.fromSeed(
    seedColor: sun,
    primary: sun,
    secondary: sky,
    error: berry,
    surface: highContrast ? Colors.white : Colors.white,
    brightness: Brightness.light,
  ).copyWith(
    onSurface: deep,
    onPrimary: deep,
  );
  // Nunito (variable) is the default body font; Baloo 2 is used for the
  // rounded headings/buttons (applied where headings are built).
  final base = ThemeData(
    colorScheme: scheme,
    fontFamily: 'Nunito',
    useMaterial3: true,
  );
  return base.copyWith(
    scaffoldBackgroundColor: cloud,
    textTheme: base.textTheme.apply(
      bodyColor: deep,
      displayColor: deep,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: cloud,
      foregroundColor: deep,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Baloo2',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: deep,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: sun,
        foregroundColor: deep,
        minimumSize: const Size(120, 56), // child-friendly tap target
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        textStyle: const TextStyle(
          fontFamily: 'Baloo2',
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: deep,
        minimumSize: const Size(120, 48),
        side: BorderSide(color: deep, width: highContrast ? 2.5 : 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: highContrast ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: highContrast
            ? BorderSide(color: deep, width: 2)
            : BorderSide.none,
      ),
    ),
  );
}

/// Extra text style for reading-ease (dyslexia-friendly) mode.
TextStyle readingEaseStyle(TextStyle base) => base.copyWith(
      height: 1.7,
      letterSpacing: 0.6,
      wordSpacing: 1.2,
      fontWeight: FontWeight.w600,
    );
