import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// JamJot design tokens — the single source of truth for the app's look.
/// 2026-11-15: NoteStar restyle (Erika): star lime #CFFF92, marker ink #111111,
/// white ground, neon violet #9B30FF accent; Fredoka headings, Nunito Sans
/// body; pill buttons and round ink-outlined cards for kids and grown-ups.
/// Token names are kept so every screen picks up the new look.
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
  static const cream = Color(0xFFFFFFFF); // NoteStar: stark white ground
  static const ink = Color(0xFF111111); // NoteStar marker ink — text, borders
  static const inkSoft = Color(0xFF4A4A4A); // secondary text
  static const neutral = Color(0xFFF1F1EC); // quiet fills
  static const outline = Color(0xFF9A9A9A); // dashed/disabled borders

  // Blueberry — progress, growth, calm (replaced teal)
  static const blueberry = Color(0xFF9B30FF); // NoteStar neon violet
  static const blueberryDark = Color(0xFF7A1FD1);
  static const blueberryLight = Color(0xFFC99BFF);
  static const blueberryTint = Color(0xFFF0E0FF);

  // Marigold — the dopamine color: rewards, streaks, celebration. Use scarcely.
  static const marigold = Color(0xFFCFFF92); // NoteStar star lime
  static const marigoldTint = Color(0xFFE6FFC4);

  // Plum — the berry currency & special accents
  static const plum = Color(0xFF9B30FF);
  static const plumDark = Color(0xFF7A1FD1);
  static const plumTint = Color(0xFFF0E0FF);

  // Leaf green — berry stems & botanical bits only (not a UI color)
  static const leaf = Color(0xFF3E7C4A);

  // Recording dot
  static const recording = Color(0xFFC7452F);

  // Stage (the one dark scene — fan celebrations)
  static const stage = Color(0xFF111111);
}

/// "The Jam Stand" — kid-screen palette (Style Menu P7).
/// Warm paper & crate-wood neutrals that stay quiet so photo-real fruit
/// characters are the most vivid thing on screen.
abstract final class JamStand {
  static const paper = Color(0xFFFFFFFF); // page background
  static const ink = Color(0xFF111111); // marker ink
  static const inkSoft = Color(0xFF4A4A4A);
  static const crate = Color(0xFF111111); // card borders (ink)
  static const leafy = Color(0xFF9B30FF); // neon violet accent
  static const amber = Color(0xFFCFFF92); // the "go" color (primary action): star lime
  static const brick = Color(0xFF9B30FF); // accent
  static const label = Color(0xFFFFFFFF); // card fill
  static const amberTint = Color(0xFFCFFF92); // nav indicator
}

/// "Calm Studio" — parent & teacher palette (Style Menu P9).
/// Near-monochrome, one blueberry accent: organized, quiet, trustworthy.
abstract final class CalmStudio {
  static const base = Color(0xFFFFFFFF); // page background
  static const ink = Color(0xFF111111);
  static const slate = Color(0xFF4A4A4A);
  static const blueberry = Color(0xFF9B30FF); // the one accent (neon violet)
  static const tint = Color(0xFFF0E0FF);
  static const gold = Color(0xFFCFFF92); // star lime, rare highlights
}

abstract final class JamJotShape {
  static const cardRadius = 24.0;
  static const buttonRadius = 100.0;
  static const chipRadius = 100.0;
  static const border = BorderSide(color: JamJotColors.ink, width: 2);

  /// The signature "sticker tilt" — apply to at most 1–2 elements per screen.
  static const stickerTilt = -0.035; // radians, ≈ -2°

  // Per-skin radii (R1 extra-round for kids, R3 gentle for grown-ups)
  static const kidCardRadius = 28.0;
  static const kidButtonRadius = 100.0; // pill
  static const grownupCardRadius = 24.0;
  static const grownupButtonRadius = 100.0; // pill
}

/// Font families bundled in assets/fonts (see pubspec.yaml).
class JamJotType {
  static const display = 'Juicebox'; // all-caps, chunky: big headlines
  static const title = 'Birdie'; // rounded geometric: titles, buttons
  static const cheer = 'Sundae'; // script: short celebration lines only
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
  // 2026-11-15 type (Erika's Work by Taylor fonts): Juicebox for big
  // headlines, Birdie for titles and buttons, Nunito Sans stays for reading.
  TextStyle? heading(TextStyle? s, double? size) => s?.copyWith(
        fontFamily: JamJotType.display,
        fontSize: size,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: JamStand.ink,
      );
  TextStyle? title(TextStyle? s) => s?.copyWith(
        fontFamily: JamJotType.title,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
        color: JamStand.ink,
      );
  final textTheme = base.copyWith(
    displayLarge: heading(base.displayLarge, null),
    displayMedium: heading(base.displayMedium, null),
    displaySmall: heading(base.displaySmall, null),
    headlineLarge: heading(base.headlineLarge, null),
    headlineMedium: heading(base.headlineMedium, null),
    headlineSmall: heading(base.headlineSmall, null),
    titleLarge: title(base.titleLarge),
    titleMedium: title(base.titleMedium),
    labelLarge: title(base.labelLarge),
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
  final base = GoogleFonts.nunitoSansTextTheme().apply(
    bodyColor: CalmStudio.ink,
    displayColor: CalmStudio.ink,
  );
  // Grown-ups: Juicebox only for the biggest display lines; Birdie for
  // headings, titles and buttons; Nunito Sans for reading.
  TextStyle? display(TextStyle? s) => s?.copyWith(
        fontFamily: JamJotType.display,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: CalmStudio.ink,
      );
  TextStyle? heading(TextStyle? s) => s?.copyWith(
        fontFamily: JamJotType.title,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: CalmStudio.ink,
      );
  final textTheme = base.copyWith(
    displayLarge: display(base.displayLarge),
    displayMedium: display(base.displayMedium),
    displaySmall: display(base.displaySmall),
    headlineLarge: heading(base.headlineLarge),
    headlineMedium: heading(base.headlineMedium),
    headlineSmall: heading(base.headlineSmall),
    titleLarge: heading(base.titleLarge),
    labelLarge: heading(base.labelLarge),
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JamJotShape.grownupCardRadius),
        side: const BorderSide(color: CalmStudio.ink, width: 2),
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
        side: const BorderSide(color: CalmStudio.ink, width: 2),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.grownupButtonRadius),
        ),
        textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: JamStand.amberTint,
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
  );
}
