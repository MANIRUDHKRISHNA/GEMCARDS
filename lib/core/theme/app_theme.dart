import 'package:flutter/material.dart';

class AppTheme {
  static const ink = Color(0xFF111312);
  static const muted = Color(0xFF68706A);
  static const surface = Color(0xFFF7F8F6);
  static const accent = Color(0xFF8EAD47);
  static const accentDark = Color(0xFF617D24);
  static const border = Color(0xFFDDE2DB);

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
        onPrimary: Colors.white,
        surface: surface,
        onSurface: ink,
      ),
      scaffoldBackgroundColor: Colors.white,
      fontFamily: 'Roboto',
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
    );
  }
}
