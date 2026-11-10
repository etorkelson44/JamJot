import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/instruments.dart';
import '../state/app_state.dart';
import '../state/wardrobe.dart';
import 'dressed_avatar.dart';
import 'letter_avatar.dart' show studentAvatarKey;

/// Where the founder's avatar-plays-instrument stills go, one per avatar
/// and instrument (e.g. assets/art/avatar_instrument/strawberry_violin.png).
/// Drop a file in and it is used automatically; until then the avatar's
/// regular still pose shows.
String avatarInstrumentStill(String avatarKey, String instrumentKey) =>
    'assets/art/avatar_instrument/${avatarKey}_$instrumentKey.png';

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
/// still when it exists, otherwise the avatar's regular pose with its worn
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
    final instruments = (active?['instruments'] as List?)?.cast<String>();
    final entry = resolveInstrument(instrument ??
        (instruments != null && instruments.isNotEmpty
            ? instruments.first
            : null));
    final still = avatarInstrumentStill(wornKey, entry.key);
    final bundled = ref.watch(_bundledAssetsProvider).valueOrNull;

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
