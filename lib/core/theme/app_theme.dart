import 'package:flutter/material.dart';

import 'app_text_styles.dart';

class AppTheme {
  static const _brand = Color(0xFFEA6B47);
  static const _accent = Color(0xFF16867A);

  static ThemeData light() => _build(brightness: Brightness.light);

  static ThemeData dark() => _build(brightness: Brightness.dark);

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF121315)
        : const Color(0xFFF5F1EA);
    final ink = isDark ? const Color(0xFFF4EEE8) : const Color(0xFF1A1B1E);
    final muted = isDark ? const Color(0xFFB8B0A8) : const Color(0xFF5E6169);
    final panel = isDark ? const Color(0xFF1D1F22) : Colors.white;
    final border = isDark ? const Color(0xFF3A3632) : const Color(0xFFEAE0D6);
    final inputBorder = isDark
        ? const Color(0xFF49433E)
        : const Color(0xFFE7DDD2);

    final scheme = ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: brightness,
      surface: panel,
      onSurface: ink,
      secondary: _accent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 34,
          color: ink,
          height: 1.1,
        ),
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: ink,
        ),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: ink),
        bodyLarge: TextStyle(fontSize: 16, color: muted, height: 1.4),
        bodyMedium: TextStyle(fontSize: 14, color: muted, height: 1.35),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.pageTitle.copyWith(color: ink),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _brand, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 52),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          side: BorderSide(color: inputBorder),
          foregroundColor: ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
