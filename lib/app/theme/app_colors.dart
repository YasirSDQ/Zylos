import 'package:flutter/material.dart';

class AppColors {
  // ── Brand / Primary ──────────────────────────────────────────
  static const Color primary = Color(0xFFFF2A55);         // Vibrant Pink/Red
  static const Color primaryDark = Color(0xFFE01B44);
  static const Color primaryLight = Color(0xFFFF5E80);
  static const Color accent = Color(0xFF7B2CBF);           // Deep Violet
  static const Color accentLight = Color(0xFF9D4EDD);

  // ── Gradient constants ────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFFF2A55), Color(0xFFFF758F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF7B2CBF), Color(0xFF9D4EDD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0D0518), Color(0xFF1E0B2B), Color(0xFF0D0518)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Status Colors ─────────────────────────────────────────────
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color successSoft = Color(0xFF059669);
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningSoft = Color(0xFFD97706);
  static const Color error = Color(0xFFEF4444); // Red
  static const Color errorSoft = Color(0xFFDC2626);
  static const Color info = Color(0xFF3B82F6); // Blue

  // ── Dark Theme (Premium Tech) ─────────────────────────────────
  static const Color darkBg = Color(0xFF0A0A0F); // Ultra dark
  static const Color darkSurface = Color(0xFF14141E);
  static const Color darkCard = Color(0xFF1C1C28);
  static const Color darkCardElevated = Color(0xFF252536);
  static const Color darkNavBar = Color(0xFF0F0F16);
  static const Color darkTextPrimary = Color(0xFFF8F8FC);
  static const Color darkTextSecondary = Color(0xFFA0A0B8);
  static const Color darkTextTertiary = Color(0xFF6B6B80);
  static const Color darkDivider = Color(0xFF2A2A3C);
  static const Color darkBorder = Color(0xFF323248);
  static const Color glassDark = Color(0x1AFFFFFF);       // 10% white
  static const Color glassDarkStrong = Color(0x2BFFFFFF); // 17% white

  // ── Light Theme (Ultra Clean) ─────────────────────────────────
  static const Color lightBg = Color(0xFFF8F9FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardElevated = Color(0xFFF0F2F5);
  static const Color lightNavBar = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF111116);
  static const Color lightTextSecondary = Color(0xFF5A5A6E);
  static const Color lightTextTertiary = Color(0xFF9292A6);
  static const Color lightDivider = Color(0xFFE5E7EB);
  static const Color lightBorder = Color(0xFFD1D5DB);
  static const Color glassLight = Color(0x0C000000);       // 5% black
}
