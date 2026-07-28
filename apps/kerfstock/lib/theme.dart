import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KerfTheme {
  // Brand Colors
  static const Color bgPrimary = Color(0xFF121212);
  static const Color bgPanel = Color(0xFF1A1A1A);
  static const Color panelBorder = Color(0xFF333333);
  static const Color accentOrange = Color(0xFFF39C12);
  static const Color accentOrangeHover = Color(0xFFE67E22);

  // Text Colors
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFFA0A0A0);

  // Status Colors
  static const Color statusRunning = Color(0xFF2ECC71);
  static const Color statusError = Color(0xFFE74C3C);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgPrimary,
      primaryColor: accentOrange,

      // Text Theme
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
          .copyWith(
            displayLarge: GoogleFonts.robotoMono(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
            headlineMedium: GoogleFonts.robotoMono(
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: const TextStyle(color: textPrimary),
            bodyMedium: const TextStyle(color: textSecondary),
          ),

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: bgPanel,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: accentOrange),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),

      // Input Decoration (Forms)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgPanel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: panelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: panelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: accentOrange),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgPanel,
          foregroundColor: accentOrange,
          side: const BorderSide(color: accentOrange),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: GoogleFonts.robotoMono(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),

      // Cards / Panels
      cardTheme: CardThemeData(
        color: bgPanel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: panelBorder),
        ),
        margin: const EdgeInsets.all(8),
      ),
    );
  }
}
