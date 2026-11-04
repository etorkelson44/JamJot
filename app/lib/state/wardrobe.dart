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
      {this.venueLevel});
  final String id;
  final String name;

  /// Placeholder art — swapped for drawn/photo pieces with the art pass.
  final String emoji;
  final int price;

  /// Unlocks only once the student has played this venue (0-based index
  /// into [venues]); null = always purchasable.
  final int? venueLevel;
}

/// The full accessory catalog: two exclusives per venue on the tour.
const accessoryCatalog = <Accessory>[
  Accessory('beret', 'Jazz Beret', '🎩', 15, venueLevel: 0),
  Accessory('candle', 'Candle-in-a-Bottle', '🕯️', 10, venueLevel: 0),
  Accessory('blue_shades', 'Round Blue Shades', '🕶️', 20, venueLevel: 1),
  Accessory('bass_pin', 'Upright-Bass Pin', '🎻', 15, venueLevel: 1),
  Accessory('leather_jacket', 'Leather Jacket', '🧥', 35, venueLevel: 2),
  Accessory('nameplate', 'Neon Nameplate', '💡', 25, venueLevel: 2),
  Accessory('bow_tie', 'Sparkly Bow Tie', '🎀', 30, venueLevel: 3),
  Accessory('golden_mic', 'Golden Microphone', '🎤', 40, venueLevel: 3),
  Accessory('white_gloves', 'White Gloves', '🧤', 30, venueLevel: 4),
  Accessory('baton', "Conductor's Baton", '🪄', 35, venueLevel: 4),
  Accessory('bandana', 'Red-Rock Bandana', '🧣', 25, venueLevel: 5),
  Accessory('hiking_boots', 'Hiking Boots', '🥾', 30, venueLevel: 5),
  Accessory('star_shades', 'Star Shades', '⭐', 40, venueLevel: 6),
  Accessory('sparkler', 'Fireworks Sparkler', '🎇', 30, venueLevel: 6),
  Accessory('champ_jacket', 'Championship Jacket', '🏆', 50, venueLevel: 7),
  Accessory('wristband', 'Light-Up Wristband', '💫', 35, venueLevel: 7),
  Accessory('stadium_scarf', 'Stadium Scarf', '🧶', 45, venueLevel: 8),
  Accessory('crown_headset', 'Crown Headset', '👑', 60, venueLevel: 8),
  Accessory('golden_cape', 'Golden Cape', '🦸', 80, venueLevel: 9),
  Accessory('jar_crown', 'Jam-Jar Crown', '🫙', 100, venueLevel: 9),
];

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
      state = Wardrobe(owned: owned, outfits: outfits);
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
