import 'dart:convert';

import 'package:flutter/services.dart';

import 'pose_stack.dart';

/// Market accessories (JJ-059-C). Each accessory is drawn once per avatar
/// and pose; the app pairs the chosen item with the avatar and pose being
/// drawn. Art lives in `assets/art/accessories/<item>/<avatar>_<pose>/`.
///
/// Where an item has no art for the avatar and pose being drawn it is
/// hidden there (never drawn wrong). Items with `released: false` are wired
/// in but cannot be worn yet.
class AccessoryPiece {
  const AccessoryPiece({required this.slot, required this.file});
  final String slot;
  final String file;
}

class AccessoryItem {
  const AccessoryItem(
      {required this.id,
      required this.name,
      required this.released,
      required this.art,
      this.display = 'display.png'});

  final String id;
  final String name;
  final bool released;

  /// The one shelf image for the Market and dressing room (not the fitted art).
  final String display;

  /// Asset path of the shelf image.
  String get displayAsset => 'assets/art/accessories/$id/$display';

  /// `<avatar>_<pose>` (e.g. `strawberry_standing`) -> pieces, bottom first.
  final Map<String, List<AccessoryPiece>> art;

  bool hasArtFor(String avatarKey, String pose) =>
      (art['${avatarKey}_$pose'] ?? const []).isNotEmpty;

  String assetFolder(String avatarKey, String pose) =>
      'assets/art/accessories/$id/${avatarKey}_$pose';
}

const String accessoryCatalogAsset = 'assets/art/accessories/catalog.json';

/// Fixed draw order among accessories that share a place in the stack.
const List<String> accessorySlotRank = [
  'behind_body',
  'shoes',
  'clothing_torso',
  'sleeves_arm_viewer_right',
  'sleeves_arm_viewer_left',
  'face',
  'hat',
];

List<AccessoryItem> parseAccessoryCatalog(String json) {
  final m = jsonDecode(json) as Map<String, dynamic>;
  return [
    for (final raw in (m['items'] as List? ?? const []))
      if (raw is Map<String, dynamic>)
        AccessoryItem(
          id: raw['id'] as String,
          name: raw['name'] as String? ?? raw['id'] as String,
          released: raw['released'] == true,
          display: raw['display'] as String? ?? 'display.png',
          art: {
            for (final e in (raw['art'] as Map<String, dynamic>? ?? const {})
                .entries)
              e.key: [
                for (final p in (e.value as List))
                  AccessoryPiece(
                      slot: (p as Map<String, dynamic>)['slot'] as String,
                      file: p['file'] as String)
              ]
          },
        )
  ];
}

Future<List<AccessoryItem>>? _catalogCache;

Future<List<AccessoryItem>> loadAccessoryCatalog() =>
    _catalogCache ??= rootBundle
        .loadString(accessoryCatalogAsset)
        .then(parseAccessoryCatalog)
        .catchError((_) => <AccessoryItem>[]);

/// The layers to draw for the items [itemIds] on [avatarKey] in [pose],
/// sorted into the fixed slot order. Items that are not released, are not in
/// the catalog, or have no art for this avatar and pose give nothing.
List<PoseAccessory> resolveAccessories(
  List<AccessoryItem> catalog,
  Iterable<String> itemIds,
  String avatarKey,
  String pose,
) {
  final out = <PoseAccessory>[];
  for (final id in itemIds) {
    for (final item in catalog) {
      if (item.id != id || !item.released || !item.hasArtFor(avatarKey, pose)) {
        continue;
      }
      final folder = item.assetFolder(avatarKey, pose);
      for (final p in item.art['${avatarKey}_$pose']!) {
        out.add(PoseAccessory(slot: p.slot, asset: '$folder/${p.file}'));
      }
    }
  }
  int rank(String slot) {
    final i = accessorySlotRank.indexOf(slot);
    return i < 0 ? accessorySlotRank.length : i;
  }

  // Stable sort: pieces of one slot keep the order they were listed in.
  final indexed = [for (var i = 0; i < out.length; i++) (i, out[i])];
  indexed.sort((a, b) {
    final c = rank(a.$2.slot).compareTo(rank(b.$2.slot));
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
