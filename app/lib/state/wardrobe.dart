import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/fan_stage.dart' show venues;

/// One closet item. Accessories belong to the STUDENT, not to the avatar
/// they arrived with: anything owned can dress any owned avatar (JJ-014).
///
/// PREVIEW NOTE: ownership and outfits persist locally (shared_preferences)
/// so the whole system is reviewable before its backend lands. The server
/// model (item kind + owned/equipped tables) is scoped in the roadmap §9
/// backend note and ships with the venue-world release.
class Accessory {
  const Accessory(this.id, this.name, this.emoji, this.price,
      {this.venueLevel, this.bundleOnly = false, this.lore = ''});
  final String id;
  final String name;

  /// Placeholder art — swapped for drawn/photo pieces with the art pass.
  final String emoji;
  final int price;

  /// Unlocks only once the student has played this venue (0-based index
  /// into [venues]); null = always purchasable.
  final int? venueLevel;

  /// Comes only with its avatar — never sold on its own.
  final bool bundleOnly;

  /// The real-world story behind the piece (hover on desktop, long-press
  /// on touch screens).
  final String lore;
}

/// The accessory catalog. Emptied 2026-11-05 (founder-directed Tour 2.0
/// reset): the old venue accessories are retired, and the new catalog —
/// venue arrival gifts + market pieces — ships with the Tour 2.0 build.
const accessoryCatalog = <Accessory>[];

/// What each avatar brings to the closet when earned (JJ-014 revision,
/// founder-directed 2026-11-04). Bundle items are auto-worn the first time
/// and shown worn in the Market; once in the closet they dress ANY avatar.
const avatarBundles = <String, List<String>>{};

Accessory? accessoryById(String id) {
  for (final a in accessoryCatalog) {
    if (a.id == id) return a;
  }
  return null;
}

String venueNameForAccessory(Accessory a) =>
    a.venueLevel == null ? '' : venues[a.venueLevel!].name;

/// Per-student wardrobe: which accessories they own, and each avatar's
/// saved outfit. Loaded from and saved to local storage.
class Wardrobe {
  const Wardrobe({this.owned = const {}, this.outfits = const {}});
  final Set<String> owned;

  /// avatarKey -> worn accessory ids.
  final Map<String, List<String>> outfits;

  List<String> outfitFor(String avatarKey) => outfits[avatarKey] ?? const [];
}

class WardrobeNotifier extends StateNotifier<Wardrobe> {
  WardrobeNotifier(this.studentId) : super(const Wardrobe()) {
    _load();
  }
  final String studentId;

  String get _ownedKey => 'jj_wardrobe_owned_$studentId';
  String get _outfitKey => 'jj_wardrobe_outfits_$studentId';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final owned =
          (prefs.getStringList(_ownedKey) ?? const <String>[]).toSet();
      final rawOutfits = prefs.getString(_outfitKey);
      final outfits = <String, List<String>>{};
      if (rawOutfits != null) {
        final decoded = jsonDecode(rawOutfits) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          outfits[k] = (v as List).cast<String>();
        });
      }
      // Keep only accessories that still exist in the catalog — retired
      // pieces disappear from the rack and from saved outfits.
      final ids = {for (final a in accessoryCatalog) a.id};
      final prunedOwned = owned.where(ids.contains).toSet();
      final prunedOutfits = <String, List<String>>{
        for (final e in outfits.entries)
          e.key: e.value.where(ids.contains).toList(),
      }..removeWhere((_, v) => v.isEmpty);
      state = Wardrobe(owned: prunedOwned, outfits: prunedOutfits);
      if (prunedOwned.length != owned.length ||
          prunedOutfits.length != outfits.length) {
        _save();
      }
    } catch (_) {/* fresh wardrobe */}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_ownedKey, state.owned.toList());
      await prefs.setString(_outfitKey, jsonEncode(state.outfits));
    } catch (_) {/* non-fatal */}
  }

  /// Add an accessory to the closet (purchase or bundle grant).
  void acquire(String accessoryId) {
    state = Wardrobe(
        owned: {...state.owned, accessoryId}, outfits: state.outfits);
    _save();
  }

  /// When an avatar is earned, its bundled accessories join the closet and
  /// become its starting outfit (unless the kid has already dressed it).
  void grantBundle(String avatarKey) {
    final bundle = avatarBundles[avatarKey] ?? const [];
    if (bundle.isEmpty) return;
    final owned = {...state.owned, ...bundle};
    final outfits = {...state.outfits};
    if ((outfits[avatarKey] ?? const []).isEmpty) {
      outfits[avatarKey] = [...bundle];
    }
    state = Wardrobe(owned: owned, outfits: outfits);
    _save();
  }

  /// Reconcile: make sure every owned avatar's bundle is in the closet
  /// (covers avatars bought before bundles existed).
  void ensureBundles(Iterable<String> ownedAvatarKeys) {
    var owned = state.owned;
    var outfits = state.outfits;
    var changed = false;
    for (final key in ownedAvatarKeys) {
      final bundle = avatarBundles[key] ?? const [];
      if (bundle.isEmpty) continue;
      if (!bundle.every(owned.contains)) {
        owned = {...owned, ...bundle};
        changed = true;
      }
      if ((outfits[key] ?? const []).isEmpty) {
        outfits = {...outfits, key: [...bundle]};
        changed = true;
      }
    }
    if (changed) {
      state = Wardrobe(owned: owned, outfits: outfits);
      _save();
    }
  }

  /// Toggle an owned accessory on one avatar's saved outfit.
  void toggleWear(String avatarKey, String accessoryId) {
    if (!state.owned.contains(accessoryId)) return;
    final outfit = [...state.outfitFor(avatarKey)];
    if (outfit.contains(accessoryId)) {
      outfit.remove(accessoryId);
    } else {
      outfit.add(accessoryId);
    }
    state = Wardrobe(
        owned: state.owned, outfits: {...state.outfits, avatarKey: outfit});
    _save();
  }
}

final wardrobeProvider = StateNotifierProvider.autoDispose
    .family<WardrobeNotifier, Wardrobe, String>(
        (ref, studentId) => WardrobeNotifier(studentId));
