import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Color System for Styluxe
class AppColors {
  // Primary Brand Colors (Emerald Luxury)
  static const Color primary = Color(0xFF10B981);       // Emerald 500
  static const Color primaryDark = Color(0xFF059669);   // Emerald 600
  static const Color primaryLight = Color(0xFFD1FAE5);  // Emerald 100
  
  // Slate Dark Neutrals
  static const Color slateDark = Color(0xFF0F172A);     // Slate 900 (Primary Text)
  static const Color slateMedium = Color(0xFF1E293B);   // Slate 800 (Card Titles)
  static const Color slateSubtle = Color(0xFF334155);   // Slate 700
  static const Color slateMuted = Color(0xFF64748B);    // Slate 500 (Secondary Text)
  static const Color slateLight = Color(0xFF94A3B8);    // Slate 400 (Placeholders)
  
  // Backgrounds & Surfaces
  static const Color bgLight = Color(0xFFF8FAFC);       // Slate 50 (Scaffold Background)
  static const Color surfaceWhite = Colors.white;
  static const Color borderColor = Color(0xFFE2E8F0);    // Slate 200
  static const Color cardBg = Color(0xFFFFFFFF);
  
  // Accents & Badges
  static const Color indigoAccent = Color(0xFF6366F1);  // Indigo Accent
  static const Color amberGold = Color(0xFFF59E0B);     // Rating Star / Warning
  static const Color roseRed = Color(0xFFF43F5E);       // Wishlist / Sale Badge
  static const Color skyBlue = Color(0xFF0EA5E9);       // Info Badge
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient luxuryGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Centralized Elevation & Shadow Utilities
class AppShadows {
  static List<BoxShadow> subtle = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.07),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> floating = [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.12),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.35),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

/// AppTheme Engine for Styluxe
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.bgLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.indigoAccent,
        surface: AppColors.surfaceWhite,
        onSurface: AppColors.slateDark,
      ),
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: TextTheme(
        // Big Brand / Display Titles
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.slateDark,
          height: 1.1,
          letterSpacing: -0.5,
        ),
        // Section Headers (H1)
        headlineLarge: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.slateDark,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.slateDark,
          height: 1.25,
        ),
        // Card Titles / Subheaders (H2)
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.slateDark,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.slateDark,
        ),
        // Body & Descriptions
        bodyLarge: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.slateMedium,
          height: 1.45,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
          color: AppColors.slateMuted,
          height: 1.4,
        ),
        // Button & Label Text
        labelLarge: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
        // Micro & Badge Text
        labelSmall: GoogleFonts.poppins(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.slateMuted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.slateDark),
        titleTextStyle: GoogleFonts.poppins(
          color: AppColors.slateDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderColor, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.roseRed, width: 1.5),
        ),
        hintStyle: GoogleFonts.poppins(
          color: AppColors.slateLight,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          alignment: Alignment.center,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          elevation: 0,
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          alignment: Alignment.center,
          side: const BorderSide(color: AppColors.borderColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          alignment: Alignment.center,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          alignment: Alignment.center,
          textStyle: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
