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
  const AccessoryPiece(
      {required this.slot,
      required this.file,
      this.replaces,
      this.whenWorn = const [],
      this.unlessWorn = const [],
      this.overflowTop,
      this.overflowBottom});
  final String slot;
  final String file;

  /// When set, this file replaces that layer of the pose instead of being
  /// drawn on top (a legs layer trimmed under boots).
  final String? replaces;

  /// Draw this piece only while all of these items are also worn (sandals
  /// that sit lower when the joggers lengthen the legs).
  final List<String> whenWorn;

  /// Leave this piece out while any of these items is also worn.
  final List<String> unlessWorn;

  /// This file's own extra height above and below the pose canvas, when it
  /// differs from the item's (a shoe moved down onto longer legs).
  final double? overflowTop;
  final double? overflowBottom;
}

class AccessoryItem {
  const AccessoryItem(
      {required this.id,
      required this.name,
      required this.released,
      required this.art,
      this.display = 'display.png',
      this.kind = '',
      this.free = false,
      this.overflowTop = 0,
      this.overflowBottom = 0,
      this.frames = const {}});

  final String id;
  final String name;
  final bool released;

  /// 'dress', 'top' or 'bottom' for clothes that follow the dress rule
  /// (JJ-062-C): a dress is a whole outfit, never worn with a top or a
  /// bottom. Empty for everything else.
  final String kind;

  /// A gift every student owns from the start (JJ-061-C); never sold.
  final bool free;

  /// Canvas pixels of art above the pose canvas in this item's files.
  final double overflowTop;

  /// Canvas pixels of art below the pose canvas in this item's files.
  final double overflowBottom;

  /// `<avatar>_<pose>` -> [x, y, side]: the larger square to frame the
  /// avatar with while this item is worn there.
  final Map<String, List<double>> frames;

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
  'shoes_under',
  'shoes',
  'clothing_torso',
  'clothing_lower',
  'pants',
  'jacket',
  'shoes_front',
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
          kind: raw['kind'] as String? ?? '',
          free: raw['free'] == true,
          overflowTop: (raw['overflow_top'] as num?)?.toDouble() ?? 0,
          overflowBottom: (raw['overflow_bottom'] as num?)?.toDouble() ?? 0,
          frames: {
            for (final e
                in (raw['frames'] as Map<String, dynamic>? ?? const {}).entries)
              if (e.value is List && (e.value as List).length == 3)
                e.key: [for (final v in e.value as List) (v as num).toDouble()]
          },
          art: {
            for (final e in (raw['art'] as Map<String, dynamic>? ?? const {})
                .entries)
              e.key: [
                for (final p in (e.value as List))
                  AccessoryPiece(
                      slot: (p as Map<String, dynamic>)['slot'] as String? ?? '',
                      file: p['file'] as String,
                      replaces: p['replaces'] as String?,
                      whenWorn: [...?(p['when_worn'] as List?)?.cast<String>()],
                      unlessWorn: [
                        ...?(p['unless_worn'] as List?)?.cast<String>()
                      ],
                      overflowTop: (p['overflow_top'] as num?)?.toDouble(),
                      overflowBottom:
                          (p['overflow_bottom'] as num?)?.toDouble())
              ]
          },
        )
  ];
}

/// The worn pieces that have to come off when [id] goes on: a dress takes
/// off tops and bottoms, and a top or a bottom takes off a dress.
List<String> outfitConflicts(
    List<AccessoryItem> catalog, String id, Iterable<String> worn) {
  String kindOf(String i) {
    for (final item in catalog) {
      if (item.id == i) return item.kind;
    }
    return '';
  }

  final k = kindOf(id);
  if (k.isEmpty) return const [];
  return [
    for (final w in worn)
      if (w != id &&
          (k == 'dress'
              ? (kindOf(w) == 'top' || kindOf(w) == 'bottom')
              : (k == 'top' || k == 'bottom') && kindOf(w) == 'dress'))
        w
  ];
}

/// [itemIds] with the dress rule applied for drawing: while a dress is
/// among them, tops and bottoms are left out (an outfit saved before the
/// rule never draws both).
List<String> applyDressRule(
    List<AccessoryItem> catalog, Iterable<String> itemIds) {
  final ids = itemIds.toList();
  String kindOf(String i) {
    for (final item in catalog) {
      if (item.id == i) return item.kind;
    }
    return '';
  }

  if (!ids.any((i) => kindOf(i) == 'dress')) return ids;
  return [
    for (final i in ids)
      if (kindOf(i) != 'top' && kindOf(i) != 'bottom') i
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
  itemIds = applyDressRule(catalog, itemIds);
  final out = <PoseAccessory>[];
  // The items that will really be drawn here; pieces can depend on them.
  final worn = <String>{
    for (final id in itemIds)
      for (final item in catalog)
        if (item.id == id && item.released && item.hasArtFor(avatarKey, pose))
          id
  };
  for (final id in itemIds) {
    for (final item in catalog) {
      if (item.id != id || !item.released || !item.hasArtFor(avatarKey, pose)) {
        continue;
      }
      final folder = item.assetFolder(avatarKey, pose);
      for (final p in item.art['${avatarKey}_$pose']!) {
        if (!p.whenWorn.every(worn.contains) ||
            p.unlessWorn.any(worn.contains)) {
          continue;
        }
        out.add(PoseAccessory(
            slot: p.slot,
            asset: '$folder/${p.file}',
            replaces: p.replaces,
            overflowTop: p.overflowTop ?? item.overflowTop,
            overflowBottom: p.overflowBottom ?? item.overflowBottom));
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

/// Ids of the released gifts every student owns without buying (JJ-061-C).
Set<String> freeAccessoryIds(List<AccessoryItem> catalog) =>
    {for (final i in catalog) if (i.released && i.free) i.id};

/// The square to frame [avatarKey] in [pose] with while [itemIds] are worn:
/// the smallest square holding every worn item's own frame, or null when no
/// worn item asks for more room.
List<double>? accessoryFrame(List<AccessoryItem> catalog,
    Iterable<String> itemIds, String avatarKey, String pose) {
  itemIds = applyDressRule(catalog, itemIds);
  double? l, t, r, b;
  for (final id in itemIds) {
    for (final item in catalog) {
      if (item.id != id || !item.released) continue;
      final f = item.frames['${avatarKey}_$pose'];
      if (f == null) continue;
      l = l == null || f[0] < l ? f[0] : l;
      t = t == null || f[1] < t ? f[1] : t;
      r = r == null || f[0] + f[2] > r ? f[0] + f[2] : r;
      b = b == null || f[1] + f[2] > b ? f[1] + f[2] : b;
    }
  }
  if (l == null || t == null || r == null || b == null) return null;
  final side = (r - l) > (b - t) ? r - l : b - t;
  return [l - (side - (r - l)) / 2, b - side, side];
}
