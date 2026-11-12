import 'package:flutter/material.dart';

import '../state/wardrobe.dart';
import 'accessory_catalog.dart';
import 'letter_avatar.dart' show berryArt, berryAvatars;
import 'standing_pose.dart';

/// Every catalog accessory now has real drawn art, tailored per character:
/// each (accessory, avatar) pair ships as a full-canvas overlay PNG drawn
/// on that avatar's measured landmarks (eyes, mouth, chin, head, hands,
/// shoes), so items land exactly right on every body (JJ-012/JJ-014 art
/// pass, founder-directed 2026-11-04).
const _tailoredAvatars = <String>{'strawberry', 'jalapeno'};

/// Draw order, lowest first: capes and jackets wrap the body, boots and
/// held pieces come next, then neckwear, then the face, then headwear.
const _wearOrder = <String>[
  'golden_cape',
  'leather_jacket',
  'champ_jacket',
  'hiking_boots',
  'candle',
  'golden_mic',
  'baton',
  'sparkler',
  'white_gloves',
  'wristband',
  'bass_pin',
  'nameplate',
  'stadium_scarf',
  'bandana',
  'bow_tie',
  'mustache',
  'blue_shades',
  'star_shades',
  'crown_headset',
  'beret',
  'jar_crown',
];

int _zOf(String id) {
  final i = _wearOrder.indexOf(id);
  return i < 0 ? _wearOrder.length : i;
}

/// Fallback fit (fractions of the avatar box) for an avatar without
/// tailored art — emoji placeholder placement.
class _Fit {
  const _Fit(this.dx, this.dy, [this.scale = 1]);
  final double dx;
  final double dy;
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
  'mustache': _Fit(0.5, 0.56, 1.1),
};

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
    // Pieces with layered art (JJ-059-C) are drawn inside the standing pose
    // at their slots; a piece with no art for this avatar is simply not
    // drawn, so the avatar falls back to its plain pose.
    if (berryAvatars.containsKey(avatarKey) && outfit.isNotEmpty) {
      return FutureBuilder<List<AccessoryItem>>(
        future: loadAccessoryCatalog(),
        builder: (context, snap) {
          final catalog = snap.data ?? const <AccessoryItem>[];
          final layered =
              resolveAccessories(catalog, outfit, avatarKey, 'standing');
          if (layered.isEmpty) return _legacy(context);
          return StandingPose(
              avatarKey: avatarKey,
              size: size,
              accessories: layered,
              frame: accessoryFrame(catalog, outfit, avatarKey, 'standing'));
        },
      );
    }
    return _legacy(context);
  }

  Widget _legacy(BuildContext context) {
    final body = berryArt(avatarKey, size) ??
        Text('🎵', style: TextStyle(fontSize: size * 0.7));
    final worn = [...outfit]..sort((a, b) => _zOf(a).compareTo(_zOf(b)));
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: body),
          for (final id in worn) ..._place(id, opacity: 1),
          if (ghost != null && !outfit.contains(ghost))
            ..._place(ghost!, opacity: 0.45),
        ],
      ),
    );
  }

  List<Widget> _place(String id, {required double opacity}) {
    final acc = accessoryById(id);
    if (acc == null) return const [];
    if (_tailoredAvatars.contains(avatarKey)) {
      // Tailored overlay: same canvas as the body, so it aligns 1:1.
      return [
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Image.asset('assets/art/acc_${id}_$avatarKey.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          ),
        ),
      ];
    }
    final fit = _defaultFit[id];
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
