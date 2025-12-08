import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF0D1B2A);
  static const Color secondary = Color(0xFF1B263B);
  static const Color accent = Color(0xFF00A8E8);
  static const Color surface = Color(0xFFF5F7FA);

  static ThemeData theme() {
    final colorScheme = const ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: surface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    return ThemeData(
      colorScheme: colorScheme,
      primaryColor: primary,
      scaffoldBackgroundColor: surface,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        shadowColor: Colors.black.withOpacity(0.08),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: TextStyle(color: primary.withOpacity(0.8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: primary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF4A5568),
        ),
      ),
    );
  }
}
