import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pose_stack.dart';

/// Layered standing poses of the three free characters, drawn from Erika's
/// Canva PDFs (2026-11-11): `assets/art/avatar_pose/<avatar>_standing/`.
String standingPoseFolder(String avatarKey) =>
    'assets/art/avatar_pose/${avatarKey}_standing';

final Map<String, Future<PoseManifest?>> _manifestCache = {};

@visibleForTesting
void clearStandingPoseCache() => _manifestCache.clear();

Future<PoseManifest?> loadStandingPose(String avatarKey) =>
    _manifestCache.putIfAbsent(avatarKey, () async {
      final folder = standingPoseFolder(avatarKey);
      try {
        return PoseManifest.parse(
            folder, await rootBundle.loadString('$folder/manifest.json'));
      } catch (_) {
        return null;
      }
    });

/// The avatar standing, framed to fill a [size] square (the manifest's
/// display_box crops the empty canvas margin). Accessories go in through
/// [accessories], at the pose's named slots.
class StandingPose extends StatelessWidget {
  const StandingPose(
      {super.key,
      required this.avatarKey,
      this.size = 120,
      this.accessories = const [],
      this.frame});

  final String avatarKey;
  final double size;
  final List<PoseAccessory> accessories;

  /// A larger square to show instead of the pose's own box, for a worn
  /// piece that needs more room (a tall hat).
  final List<double>? frame;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PoseManifest?>(
      future: loadStandingPose(avatarKey),
      builder: (context, snap) {
        final pose = snap.data;
        if (pose == null) return SizedBox(width: size, height: size);
        final box = frame ??
            (accessories.isNotEmpty ? pose.dressedDisplayBox : null) ??
            pose.displayBox ??
            const <double>[0, 0, 1000];
        return FramedPose(
            manifest: pose, box: box, accessories: accessories, size: size);
      },
    );
  }
}
