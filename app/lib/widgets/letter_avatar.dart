import 'package:flutter/material.dart';

import '../theme/jamjot_theme.dart';

/// Berry characters bought at the market (placeholder emoji — each key
/// becomes a real illustrated character later).
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
    final berry = berryAvatars[avatarKey];
    if (berry != null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: JamJotColors.blueberryTint,
          shape: BoxShape.circle,
          border: Border.all(color: JamJotColors.ink, width: 2),
        ),
        child: Text(berry, style: TextStyle(fontSize: size * 0.52)),
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
