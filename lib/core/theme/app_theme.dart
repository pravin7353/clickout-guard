import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 🎨 CORE COLORS
  static const Color primaryColor =
      Color(0xFFF7B731); // Guard Yellow (High Vis)
  static const Color primaryDark = Color(0xFFDDA320);
  static const Color backgroundColor = Color(0xFF181818); // Pitch Dark
  static const Color surfaceColor = Color(0xFF222222); // Card Background
  static const Color errorColor = Color(0xFFE53935); // Reject Red
  static const Color successColor = Color(0xFF43A047); // Approve Green

  // Text Colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color onPrimaryText = Colors.black; // Yellow ke upar Black text

  // 🌙 DARK THEME SETUP
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,

      // 🌈 COLOR SCHEME
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: onPrimaryText, // Button text color
        onSurface: textPrimary,
      ),

      // 🔤 TYPOGRAPHY (Google Fonts: Poppins)
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),

      // 📱 APP BAR THEME
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: 1.0,
        ),
      ),

      // 🔘 BUTTON THEME (High Visibility for Guards)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimaryText, // Black text on Yellow
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // 🃏 CARD THEME
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: Colors.white.withValues(alpha: 0.08)), // Subtle border
        ),
      ),

      // 📥 INPUT FIELD THEME (Login/Manual Entry)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.all(18),
        labelStyle: const TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),

      // 🔄 LOADER THEME
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
    );
  }
}
