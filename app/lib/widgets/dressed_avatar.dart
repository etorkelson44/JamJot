import 'package:flutter/material.dart';

import '../state/wardrobe.dart';
import 'letter_avatar.dart' show berryArt;

/// Where an accessory sits on an avatar, in fractions of the avatar's box.
/// Each avatar body gets its own fit so the SAME closet item sits right on
/// every character (per-avatar fit table, JJ-014 / demonstrated in the
/// 2026-11-04 pilot). Unlisted avatars fall back to the default fit.
class _Fit {
  const _Fit(this.dx, this.dy, [this.scale = 1]);
  final double dx; // 0 = left edge, 1 = right edge
  final double dy; // 0 = top edge, 1 = bottom edge
  final double scale;
}

const _defaultFit = <String, _Fit>{
  'beret': _Fit(0.28, 0.04, 1.0),
  'candle': _Fit(0.06, 0.78, 0.9),
  'blue_shades': _Fit(0.5, 0.38, 1.1),
  'bass_pin': _Fit(0.78, 0.62, 0.7),
  'leather_jacket': _Fit(0.5, 0.74, 1.2),
  'nameplate': _Fit(0.5, 0.95, 0.8),
  'bow_tie': _Fit(0.5, 0.68, 0.9),
  'golden_mic': _Fit(0.1, 0.55, 1.0),
  'white_gloves': _Fit(0.9, 0.55, 0.9),
  'baton': _Fit(0.9, 0.42, 1.0),
  'bandana': _Fit(0.5, 0.62, 1.0),
  'hiking_boots': _Fit(0.5, 0.97, 1.0),
  'star_shades': _Fit(0.5, 0.38, 1.1),
  'sparkler': _Fit(0.08, 0.4, 1.0),
  'champ_jacket': _Fit(0.5, 0.74, 1.2),
  'wristband': _Fit(0.88, 0.62, 0.8),
  'stadium_scarf': _Fit(0.5, 0.66, 1.1),
  'crown_headset': _Fit(0.5, 0.04, 1.0),
  'golden_cape': _Fit(0.93, 0.6, 1.1),
  'jar_crown': _Fit(0.5, 0.02, 1.1),
};

/// Per-avatar overrides: body shapes differ, so hats/collars move.
const _avatarFits = <String, Map<String, _Fit>>{
  'sonatina': {
    'beret': _Fit(0.24, 0.06, 1.0),
    'bow_tie': _Fit(0.5, 0.72, 0.9),
    'stadium_scarf': _Fit(0.5, 0.7, 1.1),
  },
  'blueberry': {
    'beret': _Fit(0.3, 0.1, 1.0),
    'jar_crown': _Fit(0.5, 0.06, 1.1),
  },
  'lemon': {
    'beret': _Fit(0.3, 0.12, 1.0),
  },
  'jalapeno': {
    'beret': _Fit(0.35, 0.02, 0.9),
    'bow_tie': _Fit(0.5, 0.6, 0.9),
  },
};

/// An avatar wearing its saved outfit: the body art with each worn closet
/// item pinned to its per-avatar anchor. Accessory art is emoji for now —
/// each key swaps to a drawn/photo piece later without touching callers.
class DressedAvatar extends StatelessWidget {
  const DressedAvatar(
      {super.key,
      required this.avatarKey,
      required this.outfit,
      this.size = 120,
      this.ghost});

  final String avatarKey;
  final List<String> outfit;
  final double size;

  /// An extra item previewed translucently ("imagine wearing it").
  final String? ghost;

  @override
  Widget build(BuildContext context) {
    final body = berryArt(avatarKey, size) ??
        Text('🎵', style: TextStyle(fontSize: size * 0.7));
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: body),
          for (final id in outfit) ..._place(id, opacity: 1),
          if (ghost != null && !outfit.contains(ghost))
            ..._place(ghost!, opacity: 0.45),
        ],
      ),
    );
  }

  List<Widget> _place(String id, {required double opacity}) {
    final acc = accessoryById(id);
    if (acc == null) return const [];
    final fit = _avatarFits[avatarKey]?[id] ?? _defaultFit[id];
    if (fit == null) return const [];
    final itemSize = size * 0.34 * fit.scale;
    return [
      Positioned(
        left: fit.dx * size - itemSize / 2,
        top: fit.dy * size - itemSize / 2,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Text(acc.emoji, style: TextStyle(fontSize: itemSize)),
          ),
        ),
      ),
    ];
  }
}
