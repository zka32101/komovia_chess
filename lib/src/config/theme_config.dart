import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Chess Tactics Master Theme Configuration
/// Implements Material 3 design system with light and dark modes
class ThemeConfig {
  // Private constructor to prevent instantiation
  ThemeConfig._();

  /// Light mode theme
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryLight,
          brightness: Brightness.light,
        ),
        fontFamily: GoogleFonts.roboto().fontFamily,
        textTheme: _buildLightTextTheme(),
        appBarTheme: _buildLightAppBarTheme(),
        cardTheme: _buildLightCardTheme(),
        inputDecorationTheme: _buildLightInputTheme(),
        elevatedButtonTheme: _buildElevatedButtonTheme(Brightness.light),
        outlinedButtonTheme: _buildOutlinedButtonTheme(Brightness.light),
        textButtonTheme: _buildTextButtonTheme(Brightness.light),
        iconButtonTheme: _buildIconButtonTheme(Brightness.light),
        floatingActionButtonTheme: _buildFabTheme(Brightness.light),
        scaffoldBackgroundColor: _surfaceLightBg,
        dialogTheme: _buildDialogTheme(Brightness.light),
        bottomSheetTheme: _buildBottomSheetTheme(Brightness.light),
      );

  /// Dark mode theme
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryDark,
          brightness: Brightness.dark,
        ),
        fontFamily: GoogleFonts.roboto().fontFamily,
        textTheme: _buildDarkTextTheme(),
        appBarTheme: _buildDarkAppBarTheme(),
        cardTheme: _buildDarkCardTheme(),
        inputDecorationTheme: _buildDarkInputTheme(),
        elevatedButtonTheme: _buildElevatedButtonTheme(Brightness.dark),
        outlinedButtonTheme: _buildOutlinedButtonTheme(Brightness.dark),
        textButtonTheme: _buildTextButtonTheme(Brightness.dark),
        iconButtonTheme: _buildIconButtonTheme(Brightness.dark),
        floatingActionButtonTheme: _buildFabTheme(Brightness.dark),
        scaffoldBackgroundColor: _surfaceDarkBg,
        dialogTheme: _buildDialogTheme(Brightness.dark),
        bottomSheetTheme: _buildBottomSheetTheme(Brightness.dark),
      );

  // ============================================================
  // Colors
  // ============================================================

  // Primary Colors - Light Mode
  static const Color _primaryLight = Color(0xFF2E7D32); // Chess Green
  static const Color _primaryContainerLight = Color(0xFFC8E6C9);
  static const Color _onPrimaryLight = Color(0xFFFFFFFF);

  // Primary Colors - Dark Mode
  static const Color _primaryDark = Color(0xFF81C784); // Light Green
  static const Color _primaryContainerDark = Color(0xFF1B5E20);

  // Secondary Colors - Light Mode
  static const Color _secondaryLight = Color(0xFFFF6F00); // Orange
  static const Color _secondaryContainerLight = Color(0xFFFFE0B2);
  static const Color _onSecondaryLight = Color(0xFFFFFFFF);

  // Secondary Colors - Dark Mode
  static const Color _secondaryDark = Color(0xFFFFB74D);
  static const Color _secondaryContainerDark = Color(0xFFE65100);
  static const Color _onSecondaryDark = Color(0xFF000000);

  // Neutral Colors - Light Mode
  static const Color _surfaceLightBg = Color(0xFFFAFAFA);
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _surfaceVariantLight = Color(0xFFF5F5F5);
  static const Color _onSurfaceLight = Color(0xFF1A1A1A);
  static const Color _onSurfaceVariantLight = Color(0xFF727272);

  // Neutral Colors - Dark Mode
  static const Color _surfaceDarkBg = Color(0xFF121212);
  static const Color _surfaceDark = Color(0xFF1E1E1E);
  static const Color _surfaceVariantDark = Color(0xFF2C2C2C);
  static const Color _onSurfaceDark = Color(0xFFFFFFFF);
  static const Color _onSurfaceVariantDark = Color(0xFFBDBDBD);

  // Semantic Colors
  static const Color _errorLight = Color(0xFFD32F2F);
  static const Color _successLight = Color(0xFF388E3C);
  static const Color _warningLight = Color(0xFFFBC02D);
  static const Color _infoLight = Color(0xFF1976D2);

  static const Color _errorDark = Color(0xFFF44336);
  static const Color _successDark = Color(0xFF66BB6A);
  static const Color _warningDark = Color(0xFFFDD835);
  static const Color _infoDark = Color(0xFF42A5F5);

  // ============================================================
  // Text Themes
  // ============================================================

  static TextTheme _buildLightTextTheme() => TextTheme(
        displayLarge: GoogleFonts.raleway(
          fontSize: 57,
          fontWeight: FontWeight.bold,
          color: _onSurfaceLight,
          letterSpacing: -0.25,
        ),
        displayMedium: GoogleFonts.raleway(
          fontSize: 45,
          fontWeight: FontWeight.bold,
          color: _onSurfaceLight,
          letterSpacing: 0,
        ),
        displaySmall: GoogleFonts.raleway(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: _onSurfaceLight,
          letterSpacing: 0,
        ),
        headlineLarge: GoogleFonts.roboto(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: _onSurfaceLight,
          letterSpacing: 0,
        ),
        headlineMedium: GoogleFonts.roboto(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _onSurfaceLight,
          letterSpacing: 0,
        ),
        headlineSmall: GoogleFonts.roboto(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: _onSurfaceLight,
          letterSpacing: 0,
        ),
        titleLarge: GoogleFonts.roboto(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: _onSurfaceLight,
          letterSpacing: 0,
        ),
        titleMedium: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: _onSurfaceLight,
          letterSpacing: 0.15,
        ),
        titleSmall: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _onSurfaceLight,
          letterSpacing: 0.1,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: _onSurfaceLight,
          letterSpacing: 0.5,
        ),
        bodyMedium: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: _onSurfaceLight,
          letterSpacing: 0.25,
        ),
        bodySmall: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: _onSurfaceVariantLight,
          letterSpacing: 0.4,
        ),
        labelLarge: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _onSurfaceLight,
          letterSpacing: 0.1,
        ),
        labelMedium: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _onSurfaceLight,
          letterSpacing: 0.5,
        ),
        labelSmall: GoogleFonts.roboto(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _onSurfaceLight,
          letterSpacing: 0.5,
        ),
      );

  static TextTheme _buildDarkTextTheme() => TextTheme(
        displayLarge: GoogleFonts.raleway(
          fontSize: 57,
          fontWeight: FontWeight.bold,
          color: _onSurfaceDark,
          letterSpacing: -0.25,
        ),
        displayMedium: GoogleFonts.raleway(
          fontSize: 45,
          fontWeight: FontWeight.bold,
          color: _onSurfaceDark,
          letterSpacing: 0,
        ),
        displaySmall: GoogleFonts.raleway(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: _onSurfaceDark,
          letterSpacing: 0,
        ),
        headlineLarge: GoogleFonts.roboto(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: _onSurfaceDark,
          letterSpacing: 0,
        ),
        headlineMedium: GoogleFonts.roboto(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _onSurfaceDark,
          letterSpacing: 0,
        ),
        headlineSmall: GoogleFonts.roboto(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: _onSurfaceDark,
          letterSpacing: 0,
        ),
        titleLarge: GoogleFonts.roboto(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: _onSurfaceDark,
          letterSpacing: 0,
        ),
        titleMedium: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: _onSurfaceDark,
          letterSpacing: 0.15,
        ),
        titleSmall: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _onSurfaceDark,
          letterSpacing: 0.1,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: _onSurfaceDark,
          letterSpacing: 0.5,
        ),
        bodyMedium: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: _onSurfaceDark,
          letterSpacing: 0.25,
        ),
        bodySmall: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: _onSurfaceVariantDark,
          letterSpacing: 0.4,
        ),
        labelLarge: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _onSurfaceDark,
          letterSpacing: 0.1,
        ),
        labelMedium: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _onSurfaceDark,
          letterSpacing: 0.5,
        ),
        labelSmall: GoogleFonts.roboto(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _onSurfaceDark,
          letterSpacing: 0.5,
        ),
      );

  // ============================================================
  // Component Themes
  // ============================================================

  static AppBarTheme _buildLightAppBarTheme() => AppBarTheme(
        backgroundColor: _surfaceLight,
        foregroundColor: _onSurfaceLight,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _onSurfaceLight,
        ),
      );

  static AppBarTheme _buildDarkAppBarTheme() => AppBarTheme(
        backgroundColor: _surfaceDark,
        foregroundColor: _onSurfaceDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _onSurfaceDark,
        ),
      );

  static CardTheme _buildLightCardTheme() => CardTheme(
        color: _surfaceLight,
        elevation: 2,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      );

  static CardTheme _buildDarkCardTheme() => CardTheme(
        color: _surfaceDark,
        elevation: 2,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      );

  static InputDecorationTheme _buildLightInputTheme() => InputDecorationTheme(
        filled: true,
        fillColor: _surfaceVariantLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _surfaceVariantLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _surfaceVariantLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _errorLight),
        ),
        labelStyle: GoogleFonts.roboto(
          fontSize: 14,
          color: _onSurfaceVariantLight,
        ),
        hintStyle: GoogleFonts.roboto(
          fontSize: 14,
          color: _onSurfaceVariantLight,
        ),
      );

  static InputDecorationTheme _buildDarkInputTheme() => InputDecorationTheme(
        filled: true,
        fillColor: _surfaceVariantDark,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _surfaceVariantDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _surfaceVariantDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _errorDark),
        ),
        labelStyle: GoogleFonts.roboto(
          fontSize: 14,
          color: _onSurfaceVariantDark,
        ),
        hintStyle: GoogleFonts.roboto(
          fontSize: 14,
          color: _onSurfaceVariantDark,
        ),
      );

  static ElevatedButtonThemeData _buildElevatedButtonTheme(
    Brightness brightness,
  ) {
    final isLight = brightness == Brightness.light;
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: isLight ? _primaryLight : _primaryDark,
        foregroundColor: isLight ? _onPrimaryLight : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme(
    Brightness brightness,
  ) {
    final isLight = brightness == Brightness.light;
    final primaryColor = isLight ? _primaryLight : _primaryDark;
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: BorderSide(color: primaryColor, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isLight ? _primaryLight : _primaryDark,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  static IconButtonThemeData _buildIconButtonTheme(Brightness brightness) =>
      IconButtonThemeData(
        style: IconButton.styleFrom(
          iconSize: 24,
        ),
      );

  static FloatingActionButtonThemeData _buildFabTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return FloatingActionButtonThemeData(
      backgroundColor: isLight ? _primaryLight : _primaryDark,
      foregroundColor: isLight ? _onPrimaryLight : Colors.black,
    );
  }

  static DialogTheme _buildDialogTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return DialogTheme(
      backgroundColor: isLight ? _surfaceLight : _surfaceDark,
      titleTextStyle: GoogleFonts.roboto(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: isLight ? _onSurfaceLight : _onSurfaceDark,
      ),
      contentTextStyle: GoogleFonts.roboto(
        fontSize: 14,
        color: isLight ? _onSurfaceLight : _onSurfaceDark,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  static BottomSheetThemeData _buildBottomSheetTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return BottomSheetThemeData(
      backgroundColor: isLight ? _surfaceLight : _surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      elevation: 8,
    );
  }
}
