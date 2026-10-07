import 'package:flutter/material.dart';

/// Application theme configuration for light and dark modes
class AppTheme {
  // Light mode colors
  static const Color lightPrimary = Color(0xFF2196F3);
  static const Color lightAccent = Color(0xFFFF5722);
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightError = Color(0xFFB00020);

  // Dark mode colors
  static const Color darkPrimary = Color(0xFF90CAF9);
  static const Color darkAccent = Color(0xFFFF7043);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkError = Color(0xFFCF6679);

  /// Light theme data
  static ThemeData lightTheme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: lightPrimary,
        scaffoldBackgroundColor: lightBackground,
        cardColor: lightSurface,
        colorScheme: const ColorScheme.light(
          primary: lightPrimary,
          secondary: lightAccent,
          error: lightError,
          surface: lightSurface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: lightSurface,
          foregroundColor: Color(0xFF212121),
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardTheme(
          color: lightSurface,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: lightPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        textTheme: _buildTextTheme(isDark: false),
        inputDecorationTheme: _buildInputDecorationTheme(isDark: false),
      );

  /// Dark theme data
  static ThemeData darkTheme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: darkPrimary,
        scaffoldBackgroundColor: darkBackground,
        cardColor: darkSurface,
        colorScheme: const ColorScheme.dark(
          primary: darkPrimary,
          secondary: darkAccent,
          error: darkError,
          surface: darkSurface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkSurface,
          foregroundColor: Color(0xFFFFFFFF),
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardTheme(
          color: darkSurface,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkPrimary,
            foregroundColor: const Color(0xFF121212),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        textTheme: _buildTextTheme(isDark: true),
        inputDecorationTheme: _buildInputDecorationTheme(isDark: true),
      );

  /// Build consistent text theme
  static TextTheme _buildTextTheme({required bool isDark}) {
    final baseColor = isDark ? Colors.white : const Color(0xFF212121);
    final subtleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      titleSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: baseColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: baseColor,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: subtleColor,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: subtleColor,
      ),
    );
  }

  /// Build input decoration theme
  static InputDecorationTheme _buildInputDecorationTheme(
          {required bool isDark}) =>
      InputDecorationTheme(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? AppTheme.darkError : AppTheme.lightError,
          ),
        ),
        filled: true,
        fillColor: isDark ? Colors.grey[900] : Colors.grey[50],
      );
}
