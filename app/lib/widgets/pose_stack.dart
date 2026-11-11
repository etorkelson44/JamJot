import 'dart:convert';

import 'package:flutter/material.dart';

/// A layered avatar-plays-an-instrument pose: a list of transparent PNG
/// layers that share one square canvas, drawn bottom to top, plus named
/// slots where accessories and clothing can be slipped in between layers
/// (founder decision 2026-11-10: poses are accessory/clothing-ready).
///
/// Files live in `assets/art/avatar_instrument/<avatar>_<instrument>/`
/// with a `manifest.json` next to the layer PNGs, e.g.
/// `jalapeno_violin/manifest.json`.
class PoseManifest {
  const PoseManifest(
      {required this.folder,
      required this.layers,
      required this.slots,
      this.displayBox,
      this.dressedDisplayBox});

  /// Optional square [x, y, size] on the layer canvas that frames the figure
  /// for avatar tiles (layers themselves are never trimmed).
  final List<double>? displayBox;

  /// Wider square used instead of [displayBox] when accessories are worn
  /// (crowns and tall boots reach past the plain figure's frame).
  final List<double>? dressedDisplayBox;

  /// Asset folder, no trailing slash.
  final String folder;

  /// Layer names (file name without `.png`), bottom first.
  final List<String> layers;

  /// Slot name -> where it sits: ('after' | 'before', layer name).
  final Map<String, PoseSlot> slots;

  /// Asset path of one of this pose's own layers.
  String layerAsset(String name) => '$folder/$name.png';

  static PoseManifest parse(String folder, String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    final layers = (m['layers'] as List).cast<String>();
    final slots = <String, PoseSlot>{};
    (m['accessory_slots'] as Map<String, dynamic>? ?? const {}).forEach((k, v) {
      final s = v as Map<String, dynamic>;
      if (s['after'] is String && layers.contains(s['after'])) {
        slots[k] = PoseSlot(after: true, layer: s['after'] as String);
      } else if (s['before'] is String && layers.contains(s['before'])) {
        slots[k] = PoseSlot(after: false, layer: s['before'] as String);
      }
    });
    final box = (m['display_box'] as List?)?.map((e) => (e as num).toDouble()).toList();
    final dressed = (m['dressed_display_box'] as List?)
        ?.map((e) => (e as num).toDouble())
        .toList();
    return PoseManifest(
        folder: folder,
        layers: layers,
        slots: slots,
        displayBox: box != null && box.length == 3 ? box : null,
        dressedDisplayBox:
            dressed != null && dressed.length == 3 ? dressed : null);
  }
}

class PoseSlot {
  const PoseSlot({required this.after, required this.layer});
  final bool after;
  final String layer;
}

/// An accessory to draw in a pose: a square transparent PNG on the pose's
/// canvas, put at the named slot (e.g. `hat`, `face`, `clothing_torso`).
class PoseAccessory {
  const PoseAccessory({required this.slot, required this.asset});
  final String slot;
  final String asset;
}

/// The asset paths to draw, bottom first: the pose's layers with each
/// accessory inserted at its slot. Accessories for a slot the pose does
/// not have are skipped; several for one slot keep the order given.
List<String> poseDrawOrder(
    PoseManifest manifest, List<PoseAccessory> accessories) {
  final out = <String>[];
  List<String> at(String layer, bool after) => [
        for (final a in accessories)
          if (manifest.slots[a.slot] case final s?
              when s.layer == layer && s.after == after)
            a.asset
      ];
  for (final layer in manifest.layers) {
    out.addAll(at(layer, false));
    out.add(manifest.layerAsset(layer));
    out.addAll(at(layer, true));
  }
  return out;
}

/// Draws a pose as one picture: every layer fills the same square, so the
/// stack looks identical to a single flat image.
class PoseStack extends StatelessWidget {
  const PoseStack(
      {super.key,
      required this.manifest,
      this.accessories = const [],
      this.size = 120});

  final PoseManifest manifest;
  final List<PoseAccessory> accessories;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          for (final asset in poseDrawOrder(manifest, accessories))
            Positioned.fill(
              child: Image.asset(asset,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true),
            ),
        ],
      ),
    );
  }
}
