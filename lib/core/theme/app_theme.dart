import 'package:flutter/material.dart';

class AppTheme {
  // GEMCARDS uses a crisp enterprise-blue direction with a restrained violet accent.
  static const ink = Color(0xFF10223E);
  static const muted = Color(0xFF60708A);
  static const surface = Color(0xFFF4F7FB);
  static const accent = Color(0xFF5B66D6);
  static const accentDark = Color(0xFF173F8A);
  static const success = Color(0xFF16856A);
  static const warning = Color(0xFFD98927);
  static const error = Color(0xFFC53B52);
  static const border = Color(0xFFD9E1EE);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: accentDark,
        secondary: accent,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: ink,
      ),
      scaffoldBackgroundColor: Colors.white,
      fontFamily: 'sans-serif',
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          color: ink,
          fontSize: 36,
          height: 1.12,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.1,
        ),
        headlineSmall: TextStyle(
          color: ink,
          fontSize: 28,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -.5,
        ),
        titleLarge: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: ink, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(color: ink, fontSize: 14, height: 1.45),
        bodySmall: TextStyle(color: muted, fontSize: 12, height: 1.4),
        labelLarge: TextStyle(
          color: ink,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: TextStyle(
          color: muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: TextStyle(
          color: muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentDark, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: ink.withValues(alpha: .04),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentDark,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
