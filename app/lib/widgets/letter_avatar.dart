import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/jamjot_theme.dart';

/// Pieces of final artwork delivered as PNG (they replace the drawn SVG
/// placeholders one file at a time — add each new drop here).
const finalPngArt = <String>{
  'avatar_blueberry',
};

/// Loads a piece of art by base name: Erika's final PNG when it exists,
/// otherwise the placeholder SVG.
Widget artAsset(String base, {double? width, double? height, BoxFit fit = BoxFit.contain}) {
  if (finalPngArt.contains(base)) {
    return Image.asset('assets/art/$base.png',
        width: width, height: height, fit: fit);
  }
  return SvgPicture.asset('assets/art/$base.svg',
      width: width, height: height, fit: fit);
}

/// Berry characters bought at the market (JamJot-drawn placeholders — each
/// key swaps to Erika's final artwork later, same file names).
const berryAvatars = {
  'blueberry': '🫐',
  'strawberry': '🍓',
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
      {super.key, required this.name, this.size = 42, this.avatarKey});

  final String name;
  final double size;

  /// The worn character (students.avatar_key), when there is one.
  final String? avatarKey;

  @override
  Widget build(BuildContext context) {
    final art = berryArt(avatarKey, size * 0.84);
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
    final letter =
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
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
