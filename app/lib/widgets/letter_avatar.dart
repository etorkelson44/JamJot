import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/jamjot_theme.dart';
import 'standing_pose.dart';

/// Pieces of final artwork delivered as PNG (they replace the drawn SVG
/// placeholders one file at a time — add each new drop here).
const finalPngArt = <String>{};

/// Founder-supplied photo bodies with drawn faces (JJ-012), pending the
/// final art pass.
const placeholderPngArt = <String>{
  'brand_tisdale', // Tisdale Applications imprint
  'crowd_color', // fan crowd silhouettes (founder reference style)
  'crowd_black',
  'tour_bus', // the JamJot World Tour bus
};

/// Loads the provided PNG when available, otherwise the existing SVG.

Widget artAsset(String base,
    {double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Alignment alignment = Alignment.center}) {
  if (finalPngArt.contains(base) ||
      placeholderPngArt.contains(base) ||
      base.startsWith('acc_')) {
    return Image.asset('assets/art/$base.png',
        width: width, height: height, fit: fit, alignment: alignment);
  }
  return SvgPicture.asset('assets/art/$base.svg',
      width: width, height: height, fit: fit, alignment: alignment);
}

/// The three current characters (JamJot-drawn placeholders for now; each
/// key swaps to Erika's final artwork later, same file names). The old berry
/// set was retired 2026-11-11.
const berryAvatars = {
  'strawberry': '🍓',
  'jalapeno': '🌶️',
  'kiwi': '🥝',
};

/// Every student's default band member: Keywi (JJ-040-C). A student never
/// has "no avatar" — an unset, missing or unknown key shows Keywi.
const defaultAvatarKey = 'kiwi';

/// True when [key] names a real character a student can wear.
bool isWearableAvatar(String? key) =>
    key != null && key.isNotEmpty && berryAvatars.containsKey(key);

/// The avatar to show for a student: their worn one when it is a known
/// character, otherwise Keywi.
String studentAvatarKey(String? key) =>
    isWearableAvatar(key) ? key! : defaultAvatarKey;

/// The drawn character for a berry key (null if unknown): Erika's layered
/// standing pose (2026-11-11), which replaced the flat avatar_<key>.png.
Widget? berryArt(String? key, double size) {
  if (key == null || !berryAvatars.containsKey(key)) return null;
  return StandingPose(avatarKey: key, size: size);
}

/// Avatar tile: a bought berry character when one is worn, otherwise the
/// first letter of the name. Swapped for real artwork later without
/// touching callers.
class LetterAvatar extends StatelessWidget {
  const LetterAvatar(
      {super.key,
      required this.name,
      this.size = 42,
      this.avatarKey,
      this.starterDefault = false});

  final String name;
  final double size;

  /// The worn character (students.avatar_key), when there is one.
  final String? avatarKey;

  /// For students: an unset or unknown worn avatar shows Keywi, every
  /// student's default (JJ-040-C). Grown-ups keep the letter circle.
  final bool starterDefault;

  @override
  Widget build(BuildContext context) {
    final effectiveKey =
        starterDefault ? studentAvatarKey(avatarKey) : avatarKey;
    final art = berryArt(effectiveKey, size * 0.84);
    if (art != null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: JamJotColors.blueberryTint,
          shape: BoxShape.circle,
          border: Border.all(color: JamJotColors.ink, width: 2),
        ),
        child: art,
      );
    }
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: JamJotColors.neutral,
        shape: BoxShape.circle,
        border: Border.all(color: JamJotColors.ink, width: 2),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: JamJotColors.ink,
        ),
      ),
    );
  }
}
