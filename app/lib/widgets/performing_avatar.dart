import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/instruments.dart';
import '../state/app_state.dart';
import '../state/wardrobe.dart';
import 'accessory_catalog.dart';
import 'dressed_avatar.dart';
import 'pose_stack.dart';
import 'letter_avatar.dart' show studentAvatarKey;

/// Where the founder's avatar-plays-instrument stills go, one per avatar
/// and instrument (e.g. assets/art/avatar_instrument/strawberry_violin.png).
/// Drop a file in and it is used automatically; until then the avatar's
/// regular still pose shows.
String avatarInstrumentStill(String avatarKey, String instrumentKey) =>
    'assets/art/avatar_instrument/${avatarKey}_$instrumentKey.png';

/// Folder of a layered pose (accessory-ready stack of transparent layers
/// plus manifest.json), e.g. assets/art/avatar_instrument/jalapeno_violin.
String avatarInstrumentPoseFolder(String avatarKey, String instrumentKey) =>
    'assets/art/avatar_instrument/${avatarKey}_$instrumentKey';

/// The parsed manifest of a layered pose, loaded once per folder.
final _poseManifestProvider =
    FutureProvider.family<PoseManifest?, String>((ref, folder) async {
  try {
    return PoseManifest.parse(
        folder, await rootBundle.loadString('$folder/manifest.json'));
  } catch (_) {
    return null;
  }
});

/// The layered accessory catalog, loaded once.
final accessoryItemsProvider = FutureProvider<List<AccessoryItem>>(
    (ref) => loadAccessoryCatalog());

/// Every bundled asset path, read once from the asset manifest.
final _bundledAssetsProvider = FutureProvider<Set<String>>((ref) async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest.listAssets().toSet();
  } catch (_) {
    return <String>{};
  }
});

/// The active student's avatar at their instrument: one still image, no
/// animation (founder decision 2026-11-09). Shows the avatar+instrument
/// pose (layered) or still when it exists, otherwise the avatar's regular pose with its worn
/// outfit. Applies to every avatar and every instrument, piano included.
class PerformingAvatar extends ConsumerWidget {
  const PerformingAvatar({super.key, this.size = 84, this.instrument});

  final double size;

  /// The instrument being practiced; falls back to the student's first
  /// listed instrument.
  final String? instrument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeStudentProvider);
    final wornKey = studentAvatarKey(active?['avatar_key'] as String?);
    final sid = active?['id'] as String?;
    final instruments = active == null ? null : instrumentsOf(active);
    final entry = resolveInstrument(instrument ??
        (instruments != null && instruments.isNotEmpty
            ? instruments.first
            : null));
    final still = avatarInstrumentStill(wornKey, entry.key);
    final poseFolder = avatarInstrumentPoseFolder(wornKey, entry.key);
    final bundled = ref.watch(_bundledAssetsProvider).valueOrNull;

    // A layered pose (accessory-ready) wins over a flat still.
    if (bundled != null && bundled.contains('$poseFolder/manifest.json')) {
      final pose = ref.watch(_poseManifestProvider(poseFolder)).valueOrNull;
      if (pose != null) {
        // Worn pieces fitted to this pose are drawn at their slots; a piece
        // with no art for this pose is left off (plain pose fallback).
        final catalog =
            ref.watch(accessoryItemsProvider).valueOrNull ?? const [];
        final worn = sid == null
            ? const <String>[]
            : ref.watch(wardrobeProvider(sid)).outfitFor(wornKey);
        final accessories =
            resolveAccessories(catalog, worn, wornKey, entry.key);
        final frame = accessoryFrame(catalog, worn, wornKey, entry.key);
        if (frame != null && accessories.isNotEmpty) {
          return FramedPose(
              manifest: pose,
              box: frame,
              accessories: accessories,
              size: size * 1.35);
        }
        return PoseStack(
            manifest: pose, accessories: accessories, size: size * 1.35);
      }
    }

    if (bundled != null && bundled.contains(still)) {
      return Image.asset(still,
          width: size * 1.35, height: size * 1.35, fit: BoxFit.contain);
    }
    final outfit = sid == null
        ? const <String>[]
        : ref.watch(wardrobeProvider(sid)).outfitFor(wornKey);
    return DressedAvatar(avatarKey: wornKey, outfit: outfit, size: size);
  }
}
