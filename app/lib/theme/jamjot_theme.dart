import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// JamJot design tokens — the single source of truth for the app's look.
/// Blueberry + Marigold scheme chosen 2026-10-29 (see mockup canvas).
abstract final class JamJotColors {
  // Ground & ink
  static const cream = Color(0xFFFAF6EE); // warm paper background
  static const ink = Color(0xFF26323E); // deep ink navy — text, borders
  static const inkSoft = Color(0xFF5B6670); // secondary text
  static const neutral = Color(0xFFEFE8DA); // quiet fills
  static const outline = Color(0xFF9AA4AD); // dashed/disabled borders

  // Blueberry — progress, growth, calm (replaced teal)
  static const blueberry = Color(0xFF4A5FAE);
  static const blueberryDark = Color(0xFF36467F);
  static const blueberryLight = Color(0xFF9AA9DC);
  static const blueberryTint = Color(0xFFE7EBF8);

  // Marigold — the dopamine color: rewards, streaks, celebration. Use scarcely.
  static const marigold = Color(0xFFFFBE2E);
  static const marigoldTint = Color(0xFFFFF2CF);

  // Plum — the berry currency & special accents
  static const plum = Color(0xFF6C4A91);
  static const plumDark = Color(0xFF523770);
  static const plumTint = Color(0xFFEEE7F6);

  // Leaf green — berry stems & botanical bits only (not a UI color)
  static const leaf = Color(0xFF3E7C4A);

  // Recording dot
  static const recording = Color(0xFFC7452F);

  // Stage (the one dark scene — fan celebrations)
  static const stage = Color(0xFF1B242E);
}

abstract final class JamJotShape {
  static const cardRadius = 20.0;
  static const buttonRadius = 18.0;
  static const chipRadius = 12.0;
  static const border = BorderSide(color: JamJotColors.ink, width: 2);
  /// The signature "sticker tilt" — apply to at most 1–2 elements per screen.
  static const stickerTilt = -0.035; // radians, ≈ -2°
}

ThemeData buildJamJotTheme() {
  final textTheme = GoogleFonts.spaceGroteskTextTheme().apply(
    bodyColor: JamJotColors.ink,
    displayColor: JamJotColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: JamJotColors.cream,
    colorScheme: const ColorScheme.light(
      primary: JamJotColors.ink,
      secondary: JamJotColors.blueberry,
      tertiary: JamJotColors.marigold,
      surface: Colors.white,
      error: JamJotColors.recording,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: JamJotColors.ink,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: JamJotColors.cream,
      foregroundColor: JamJotColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
        side: JamJotShape.border,
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: JamJotColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.buttonRadius),
        ),
        textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: JamJotColors.ink,
        side: JamJotShape.border,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.buttonRadius),
        ),
        textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: JamJotColors.marigoldTint,
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
  );
}
