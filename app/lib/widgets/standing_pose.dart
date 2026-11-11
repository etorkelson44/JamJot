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
      this.accessories = const []});

  final String avatarKey;
  final double size;
  final List<PoseAccessory> accessories;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PoseManifest?>(
      future: loadStandingPose(avatarKey),
      builder: (context, snap) {
        final pose = snap.data;
        if (pose == null) return SizedBox(width: size, height: size);
        final box = pose.displayBox ?? const [0, 0, 1000];
        final k = size / box[2];
        return SizedBox(
          width: size,
          height: size,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 0,
              minHeight: 0,
              maxWidth: 1000 * k,
              maxHeight: 1000 * k,
              child: Transform.translate(
                offset: Offset(-box[0] * k, -box[1] * k),
                child: PoseStack(
                    manifest: pose, accessories: accessories, size: 1000 * k),
              ),
            ),
          ),
        );
      },
    );
  }
}
