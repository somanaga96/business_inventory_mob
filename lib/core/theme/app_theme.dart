import 'package:flutter/material.dart';

const primary = Color(0xFF6256F6);
const ink = Color(0xFF17213A);

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ),
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF10131B)
        : const Color(0xFFF7F8FC),
    cardTheme: CardThemeData(
      color: isDark ? const Color(0xFF191E2A) : Colors.white,
    ),
  );
}
