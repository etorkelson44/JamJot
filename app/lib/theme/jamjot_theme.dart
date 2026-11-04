import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// JamJot design tokens — the single source of truth for the app's look.
/// Blueberry + Marigold scheme chosen 2026-10-29 (see mockup canvas).
///
/// 2026-11-03: two skins chosen by Erika from the Style Menu:
///  • Kid screens — "The Jam Stand": farmers'-market palette (P7),
///    Baloo 2 + Nunito Sans (F2), pill buttons (B1), extra-round corners (R1),
///    paper-label cards (C4), photo-real sticker characters (I3).
///  • Grown-up screens — "Calm Studio": clean-focus palette (P9),
///    Varela Round + Source Sans 3 (F8), soft-square buttons (B3),
///    gentle corners (R3), quiet shadow cards (C2).
/// The skin switches automatically with activeStudentProvider (kid driving
/// = Jam Stand; grown-up driving = Calm Studio).
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

/// "The Jam Stand" — kid-screen palette (Style Menu P7).
/// Warm paper & crate-wood neutrals that stay quiet so photo-real fruit
/// characters are the most vivid thing on screen.
abstract final class JamStand {
  static const paper = Color(0xFFF8F3E9); // page background
  static const ink = Color(0xFF2E2A26); // warm near-black
  static const inkSoft = Color(0xFF6B6257);
  static const crate = Color(0xFFB98A5A); // wood / label borders
  static const leafy = Color(0xFF7A9E6E); // produce green
  static const amber = Color(0xFFE8A23D); // the "go" color (primary action)
  static const brick = Color(0xFFC96F4A); // warm accent
  static const label = Color(0xFFFFF8E7); // paper-label card fill
  static const amberTint = Color(0xFFFFE3B3); // nav indicator
}

/// "Calm Studio" — parent & teacher palette (Style Menu P9).
/// Near-monochrome, one blueberry accent: organized, quiet, trustworthy.
abstract final class CalmStudio {
  static const base = Color(0xFFF7F5F1); // page background
  static const ink = Color(0xFF26323E);
  static const slate = Color(0xFF5B6670);
  static const blueberry = Color(0xFF4A5FAE); // the one accent
  static const tint = Color(0xFFE7EBF8);
  static const gold = Color(0xFFFFBE2E); // kept for rare highlights
}

abstract final class JamJotShape {
  static const cardRadius = 20.0;
  static const buttonRadius = 18.0;
  static const chipRadius = 12.0;
  static const border = BorderSide(color: JamJotColors.ink, width: 2);

  /// The signature "sticker tilt" — apply to at most 1–2 elements per screen.
  static const stickerTilt = -0.035; // radians, ≈ -2°

  // Per-skin radii (R1 extra-round for kids, R3 gentle for grown-ups)
  static const kidCardRadius = 28.0;
  static const kidButtonRadius = 100.0; // pill
  static const grownupCardRadius = 12.0;
  static const grownupButtonRadius = 10.0; // soft square
}

enum JamJotSkin { kid, grownup }

ThemeData buildJamJotTheme([JamJotSkin skin = JamJotSkin.grownup]) {
  return switch (skin) {
    JamJotSkin.kid => _jamStandTheme(),
    JamJotSkin.grownup => _calmStudioTheme(),
  };
}

/// Kid skin — The Jam Stand.
ThemeData _jamStandTheme() {
  final base = GoogleFonts.nunitoSansTextTheme().apply(
    bodyColor: JamStand.ink,
    displayColor: JamStand.ink,
  );
  // Baloo 2 for headings & fun moments; Nunito Sans for everything readable.
  TextStyle? heading(TextStyle? s, double? size) => s == null
      ? null
      : GoogleFonts.baloo2(
          textStyle: s,
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: JamStand.ink,
        );
  final textTheme = base.copyWith(
    displayLarge: heading(base.displayLarge, null),
    displayMedium: heading(base.displayMedium, null),
    displaySmall: heading(base.displaySmall, null),
    headlineLarge: heading(base.headlineLarge, null),
    headlineMedium: heading(base.headlineMedium, null),
    headlineSmall: heading(base.headlineSmall, null),
    titleLarge: heading(base.titleLarge, null),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: JamStand.paper,
    colorScheme: const ColorScheme.light(
      primary: JamStand.ink,
      secondary: JamStand.leafy,
      tertiary: JamStand.amber,
      surface: Colors.white,
      error: JamJotColors.recording,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: JamStand.ink,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: JamStand.paper,
      foregroundColor: JamStand.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(letterSpacing: -0.3),
    ),
    // C4 paper label: kraft-tone fill with a crate-wood border, extra round.
    cardTheme: CardThemeData(
      color: JamStand.label,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JamJotShape.kidCardRadius),
        side: const BorderSide(color: JamStand.crate, width: 2),
      ),
      margin: EdgeInsets.zero,
    ),
    // B1 pill buttons; amber = the one "go" color.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: JamStand.amber,
        foregroundColor: JamStand.ink,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.kidButtonRadius),
        ),
        textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: JamStand.ink,
        side: const BorderSide(color: JamStand.ink, width: 2),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.kidButtonRadius),
        ),
        textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: JamStand.amberTint,
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
  );
}

/// Grown-up skin — Calm Studio.
ThemeData _calmStudioTheme() {
  final base = GoogleFonts.sourceSans3TextTheme().apply(
    bodyColor: CalmStudio.ink,
    displayColor: CalmStudio.ink,
  );
  TextStyle? heading(TextStyle? s) => s == null
      ? null
      : GoogleFonts.varelaRound(
          textStyle: s,
          fontWeight: FontWeight.w600,
          color: CalmStudio.ink,
        );
  final textTheme = base.copyWith(
    displayLarge: heading(base.displayLarge),
    displayMedium: heading(base.displayMedium),
    displaySmall: heading(base.displaySmall),
    headlineLarge: heading(base.headlineLarge),
    headlineMedium: heading(base.headlineMedium),
    headlineSmall: heading(base.headlineSmall),
    titleLarge: heading(base.titleLarge),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: CalmStudio.base,
    colorScheme: const ColorScheme.light(
      primary: CalmStudio.blueberry,
      secondary: CalmStudio.slate,
      tertiary: CalmStudio.gold,
      surface: Colors.white,
      error: JamJotColors.recording,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: CalmStudio.ink,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: CalmStudio.base,
      foregroundColor: CalmStudio.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(letterSpacing: -0.2),
    ),
    // C2 quiet shadow cards: no border, one soft shadow, gentle corners.
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: const Color(0x3326323E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JamJotShape.grownupCardRadius),
      ),
      margin: EdgeInsets.zero,
    ),
    // B3 soft-square buttons; blueberry = the one accent.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CalmStudio.blueberry,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.grownupButtonRadius),
        ),
        textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CalmStudio.ink,
        side: const BorderSide(color: CalmStudio.slate, width: 1.5),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.grownupButtonRadius),
        ),
        textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: CalmStudio.tint,
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
  );
}
