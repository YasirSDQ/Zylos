import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextTheme getTextTheme(BuildContext context, {required bool isDark}) {
    final baseTextColor = isDark ? const Color(0xFFF8F8FC) : const Color(0xFF111116);
    final secondaryTextColor = isDark ? const Color(0xFFA0A0B8) : const Color(0xFF5A5A6E);

    return TextTheme(
      // Headings -> Plus Jakarta Sans
      displayLarge: GoogleFonts.plusJakartaSans(fontSize: 57, fontWeight: FontWeight.bold, color: baseTextColor),
      displayMedium: GoogleFonts.plusJakartaSans(fontSize: 45, fontWeight: FontWeight.bold, color: baseTextColor),
      displaySmall: GoogleFonts.plusJakartaSans(fontSize: 36, fontWeight: FontWeight.bold, color: baseTextColor),
      headlineLarge: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.bold, color: baseTextColor),
      headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700, color: baseTextColor),
      headlineSmall: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700, color: baseTextColor),
      titleLarge: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w600, color: baseTextColor),
      titleMedium: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: baseTextColor),
      titleSmall: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: baseTextColor),

      // Body -> Inter
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal, color: baseTextColor),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal, color: baseTextColor),
      bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal, color: secondaryTextColor),
      
      // Labels / Buttons -> Inter
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: baseTextColor),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: baseTextColor),
      labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: secondaryTextColor),
    );
  }
}
