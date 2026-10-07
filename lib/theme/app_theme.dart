import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF4F46E5); // Indigo 600
  static const primaryLight = Color(0xFF6366F1); // Indigo 500
  static const secondaryColor = Color(0xFF06B6D4); // Cyan 500
  static const accentColor = Color(0xFFF43F5E); // Rose 500
  static const backgroundColor = Color(0xFFF8FAFC); // Slate 50
  static const surfaceColor = Colors.white;
  static const cardColor = Colors.white;
  static const textDark = Color(0xFF1E293B); // Slate 800
  static const textMuted = Color(0xFF64748B); // Slate 500

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        error: accentColor,
        background: backgroundColor,
        surface: surfaceColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: textDark),
      ),
      cardTheme: CardTheme(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
