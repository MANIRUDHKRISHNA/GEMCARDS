import 'package:flutter/material.dart';

class AppTheme {
  // GEMCARDS uses a crisp enterprise-blue direction with a restrained violet accent.
  static const ink = Color(0xFF10223E);
  static const muted = Color(0xFF60708A);
  static const surface = Color(0xFFF6F8FC);
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
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentDark, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
