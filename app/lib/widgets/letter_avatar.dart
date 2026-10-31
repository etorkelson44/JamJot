import 'package:flutter/material.dart';

import '../theme/jamjot_theme.dart';

/// Placeholder avatar: the first letter of the name on a neutral tile.
/// Swapped for real artwork/photos later without touching callers.
class LetterAvatar extends StatelessWidget {
  const LetterAvatar({super.key, required this.name, this.size = 42});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
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
