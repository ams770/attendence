import 'package:flutter/material.dart';

/// Clean, minimal Material 3 theme definitions for light and dark modes.
class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E3A8A),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: const CardThemeData(elevation: 1, margin: EdgeInsets.all(8)),
    );
  }

  static ThemeData get darkTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B82F6),
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: const CardThemeData(elevation: 1, margin: EdgeInsets.all(8)),
    );
  }
}
