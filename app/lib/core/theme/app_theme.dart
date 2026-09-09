import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App theme configuration for BookBridge.
///
/// This class provides a centralized theme setup for the application,
/// following the "Knowledge & Trust" visual identity.
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // "Knowledge & Trust" Palette - Public constants for screen use
  static const Color scholarBlue = Color(0xFF1A4D8C); // Trust, stability
  static const Color bridgeOrange = Color(0xFFF2994A); // Action, energy
  static const Color growthGreen = Color(0xFF27AE60); // Impact, growth
  static const Color paperWhite = Color(0xFFF9F9F9); // Clean, accessible
  static const Color inkBlack = Color(0xFF2D3436); // Readability
  static const Color surface = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color lightGray = Color(0xFF95A5A6);

  // Dark Palette
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkDivider = Color(0xFF2C2C2C);
  static const Color darkLightGray = Color(0xFF636E72);

  /// Returns the light theme for BookBridge.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // Color scheme
      colorScheme: ColorScheme.light(
        surface: surface,
        primary: scholarBlue,
        secondary: bridgeOrange,
        tertiary: growthGreen,
        onSurface: inkBlack,
        onPrimary: Colors.white,
        error: const Color(0xFFE74C3C),
        surfaceContainerHighest: paperWhite,
        outline: divider,
      ),
      // Scaffold background
      scaffoldBackgroundColor: paperWhite,
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: scholarBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.montserrat(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      // Card theme
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: scholarBlue, width: 2),
        ),
        hintStyle: GoogleFonts.inter(color: lightGray, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: scholarBlue, fontSize: 14),
      ),
      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bridgeOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scholarBlue,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scholarBlue,
          side: const BorderSide(color: scholarBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      // Text themes
      textTheme: TextTheme(
        displayLarge: GoogleFonts.montserrat(
          color: inkBlack,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.montserrat(
          color: inkBlack,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: GoogleFonts.montserrat(
          color: inkBlack,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.montserrat(
          color: inkBlack,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: GoogleFonts.montserrat(
          color: inkBlack,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.montserrat(
          color: inkBlack,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: GoogleFonts.inter(color: inkBlack, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: inkBlack, fontSize: 14),
        bodySmall: GoogleFonts.inter(color: lightGray, fontSize: 12),
        labelLarge: GoogleFonts.inter(
          color: scholarBlue,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      // Icon theme
      iconTheme: const IconThemeData(color: scholarBlue, size: 24),
    );
  }

  /// Returns the dark theme for BookBridge.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      // Color scheme
      colorScheme: ColorScheme.dark(
        surface: darkSurface,
        primary: scholarBlue,
        secondary: bridgeOrange,
        tertiary: growthGreen,
        onSurface: Colors.white,
        onPrimary: Colors.white,
        error: const Color(0xFFE74C3C),
        surfaceContainerHighest: darkSurface,
        outline: darkDivider,
      ),
      // Scaffold background
      scaffoldBackgroundColor: darkBackground,
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.montserrat(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      // Card theme
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: scholarBlue, width: 2),
        ),
        hintStyle: GoogleFonts.inter(color: darkLightGray, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: scholarBlue, fontSize: 14),
      ),
      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bridgeOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scholarBlue,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scholarBlue,
          side: const BorderSide(color: scholarBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      // Text themes
      textTheme: TextTheme(
        displayLarge: GoogleFonts.montserrat(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.montserrat(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: GoogleFonts.montserrat(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.montserrat(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: GoogleFonts.montserrat(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.montserrat(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        bodySmall: GoogleFonts.inter(color: darkLightGray, fontSize: 12),
        labelLarge: GoogleFonts.inter(
          color: scholarBlue,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      // Icon theme
      iconTheme: const IconThemeData(color: scholarBlue, size: 24),
    );
  }
}
