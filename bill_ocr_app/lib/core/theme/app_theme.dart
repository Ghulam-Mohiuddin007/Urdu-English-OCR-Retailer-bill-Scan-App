import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppHaptics {
  static void light() => HapticFeedback.lightImpact();
  static void selection() => HapticFeedback.selectionClick();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
}

class AppTheme {
  // Bespoke Color Palette: Obsidian, Emerald Cashmere, Mandi Gold
  static const Color darkCanvas = Color(0xFF090D16);
  static const Color darkSurface = Color(0xFF131D2E);
  static const Color darkSurfaceElevated = Color(0xFF1B273D);
  static const Color darkBorder = Color(0xFF24324D);

  static const Color primary = Color(0xFF0D9488); // Deep Teal
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color primaryLight = Color(0xFF14B8A6);

  static const Color accentEmerald = Color(0xFF10B981); // Emerald
  static const Color accentGold = Color(0xFFF59E0B); // Mandi Gold
  static const Color accentCyan = Color(0xFF06B6D4); // Scan Laser Beam

  // Backward-compatible tokens
  static const Color accent = accentEmerald;
  static const Color accentMint = Color(0xFFD1FAE5);
  static const Color background = darkCanvas;
  static const Color surface = darkSurface;
  static const Color textPrimary = textDarkPrimary;
  static const Color textSecondary = textDarkSecondary;

  // Light Theme Neutrals
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Text
  static const Color textDarkPrimary = Color(0xFFF8FAFC);
  static const Color textDarkSecondary = Color(0xFF94A3B8);
  static const Color textDarkMuted = Color(0xFF64748B);

  static const Color textLightPrimary = Color(0xFF0F172A);
  static const Color textLightSecondary = Color(0xFF475569);
  static const Color textLightMuted = Color(0xFF94A3B8);

  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);

  /// Human-crafted dark theme (default for scanner focus)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkCanvas,
      colorScheme: const ColorScheme.dark(
        primary: accentEmerald,
        secondary: accentGold,
        surface: darkSurface,
        surfaceContainerHighest: darkSurfaceElevated,
        error: errorRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: darkCanvas,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
    );
  }

  /// Elegant light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accentEmerald,
        surface: lightSurface,
        surfaceContainerHighest: lightSurfaceAlt,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: lightBg,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
    );
  }

  /// Typography helper for Urdu (Noto Nastaliq Urdu)
  static TextStyle urduTextStyle({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double height = 1.9,
    double letterSpacing = 0.0,
  }) {
    return GoogleFonts.notoNastaliqUrdu(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textDarkPrimary,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Typography helper for English & tabular numerals (Inter with tabular figures)
  static TextStyle englishTextStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double? height,
    double letterSpacing = -0.2,
    bool tabularNumbers = false,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textDarkPrimary,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: tabularNumbers ? const [FontFeature.tabularFigures()] : null,
    );
  }

  /// Handcrafted Glassmorphic Card Decoration
  static BoxDecoration glassCardDecoration({
    Color? backgroundColor,
    Color? borderColor,
    double borderRadius = 20.0,
    double borderWidth = 1.0,
    bool hasGlow = false,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? darkSurface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.08),
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          offset: const Offset(0, 10),
          blurRadius: 24,
          spreadRadius: -4,
        ),
        if (hasGlow)
          BoxShadow(
            color: accentEmerald.withValues(alpha: 0.15),
            offset: const Offset(0, 0),
            blurRadius: 20,
            spreadRadius: 2,
          ),
      ],
    );
  }
}
