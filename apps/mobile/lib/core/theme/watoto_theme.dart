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
}

ThemeData buildWatotoTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: WatotoColors.sun,
    primary: WatotoColors.sun,
    secondary: WatotoColors.sky,
    error: WatotoColors.berry,
    surface: Colors.white,
  );
  // Nunito (variable) is the default body font; Baloo 2 is used for the
  // rounded headings/buttons (applied where headings are built).
  final base = ThemeData(colorScheme: scheme, fontFamily: 'Nunito');
  return base.copyWith(
    scaffoldBackgroundColor: WatotoColors.cloud,
    textTheme: base.textTheme.apply(
      bodyColor: WatotoColors.deep,
      displayColor: WatotoColors.deep,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: WatotoColors.sun,
        foregroundColor: WatotoColors.deep,
        minimumSize: const Size(120, 56), // child-friendly tap target
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        textStyle: const TextStyle(
            fontFamily: 'Baloo2', fontSize: 20, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
