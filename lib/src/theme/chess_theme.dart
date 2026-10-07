import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Chess app theming with light and dark mode support
class ChessTheme {
  // Light mode colors
  static const Color lightPrimary = Color(0xFF2196F3);
  static const Color lightPrimaryVariant = Color(0xFF1976D2);
  static const Color lightSecondary = Color(0xFFFF9800);
  static const Color lightSecondaryVariant = Color(0xFFF57C00);
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightError = Color(0xFFD32F2F);

  // Dark mode colors
  static const Color darkPrimary = Color(0xFF64B5F6);
  static const Color darkPrimaryVariant = Color(0xFF42A5F5);
  static const Color darkSecondary = Color(0xFFFFB74D);
  static const Color darkSecondaryVariant = Color(0xFFFFA726);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkError = Color(0xFFEF5350);

  // Chess-specific colors
  static const Color whitePieceColor = Color(0xFFF0F0F0);
  static const Color blackPieceColor = Color(0xFF2C2C2C);
  static const Color lightSquareColor = Color(0xFFF0D9B5);
  static const Color darkSquareColor = Color(0xFFB58863);
  static const Color selectedSquareColor = Color(0xFFBACB44);
  static const Color hintSquareColor = Color(0xFFBBCA33);

  /// Light theme configuration
  static ThemeData getLightTheme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: lightPrimary,
        primaryColorLight: lightPrimary,
        primaryColorDark: lightPrimaryVariant,
        scaffoldBackgroundColor: lightBackground,
        colorScheme: const ColorScheme.light(
          primary: lightPrimary,
          primaryContainer: lightPrimaryVariant,
          secondary: lightSecondary,
          secondaryContainer: lightSecondaryVariant,
          surface: lightSurface,
          error: lightError,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black87,
          onError: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardTheme(
          color: lightSurface,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: lightPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: lightPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            side: const BorderSide(color: lightPrimary, width: 2),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
          displayMedium: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
          displaySmall: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
          headlineMedium: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          headlineSmall: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          titleLarge: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          titleMedium: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          bodyLarge: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
          ),
          bodyMedium: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
          ),
          bodySmall: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.black54,
          ),
          labelLarge: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: lightPrimary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: lightError, width: 2),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.grey[200],
          selectedColor: lightPrimary,
          labelStyle: GoogleFonts.poppins(fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

  /// Dark theme configuration
  static ThemeData getDarkTheme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: darkPrimary,
        primaryColorLight: darkPrimary,
        primaryColorDark: darkPrimaryVariant,
        scaffoldBackgroundColor: darkBackground,
        colorScheme: const ColorScheme.dark(
          primary: darkPrimary,
          primaryContainer: darkPrimaryVariant,
          secondary: darkSecondary,
          secondaryContainer: darkSecondaryVariant,
          surface: darkSurface,
          error: darkError,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onError: Colors.black,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: darkSurface,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
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
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: darkPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            side: const BorderSide(color: darkPrimary, width: 2),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          displayMedium: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          displaySmall: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          headlineMedium: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          headlineSmall: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          titleLarge: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          titleMedium: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
          bodyLarge: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
          bodyMedium: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.white70,
          ),
          bodySmall: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.white54,
          ),
          labelLarge: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: darkPrimary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: darkError, width: 2),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF2C2C2C),
          selectedColor: darkPrimary,
          labelStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
}
