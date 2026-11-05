import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/jamjot_theme.dart';

/// Pieces of final artwork delivered as PNG (they replace the drawn SVG
/// placeholders one file at a time — add each new drop here).
const finalPngArt = <String>{};

/// Founder-supplied photo bodies with drawn faces (JJ-012), pending the
/// final art pass.
const placeholderPngArt = <String>{
  'avatar_strawberry',
  'avatar_jalapeno',
  'avatar_grape',
  'avatar_lemon',
  'avatar_raspberry',
  'avatar_blueberry',
  'avatar_sonatina', // JJ-011/JJ-012 starter: founder's seed photo, rigged
  'acc_mustache', // Jalapresto's bundled accessory
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
  if (finalPngArt.contains(base) || placeholderPngArt.contains(base)) {
    return Image.asset('assets/art/$base.png',
        width: width, height: height, fit: fit, alignment: alignment);
  }
  return SvgPicture.asset('assets/art/$base.svg',
      width: width, height: height, fit: fit, alignment: alignment);
}

/// Berry characters bought at the market (JamJot-drawn placeholders — each
/// key swaps to Erika's final artwork later, same file names).
const berryAvatars = {
  'sonatina': '🌱', // Sonatina Sprout — every student's free starter (JJ-011)
  'blueberry': '🫐',
  'strawberry': '🍓',
  'jalapeno': '🌶️',
  'grape': '🍇',
  'lemon': '🍋',
  'blackberry': '🥷',
  'raspberry': '👑',
  'melon': '🤖',
  'dragonfruit': '🐉',
  'golden': '⭐',
};

/// The drawn character for a berry key (null if unknown).
Widget? berryArt(String? key, double size) {
  if (key == null || !berryAvatars.containsKey(key)) return null;
  return artAsset('avatar_$key', width: size, height: size);
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

  /// For students: no worn avatar yet means Sonatina Sprout, the free
  /// starter every new student begins with (JJ-011). Grown-ups keep the
  /// letter circle.
  final bool starterDefault;

  @override
  Widget build(BuildContext context) {
    final effectiveKey =
        avatarKey ?? (starterDefault ? 'sonatina' : null);
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
