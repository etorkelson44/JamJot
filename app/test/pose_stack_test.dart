import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/widgets/pose_stack.dart';

void main() {
  const folder = 'assets/art/avatar_instrument/jalapeno_violin';
  final manifest = PoseManifest.parse(
      folder, File('$folder/manifest.json').readAsStringSync());

  test('draws the pose layers bottom to top with no accessories', () {
    final order = poseDrawOrder(manifest, const []);
    expect(order.length, manifest.layers.length);
    expect(order.first, '$folder/1_pepper_body.png');
    expect(order.last, '$folder/9_right_arm_bow_hand.png');
  });

  test('inserts a fictional accessory at its slot', () {
    final order = poseDrawOrder(manifest, const [
      PoseAccessory(slot: 'hat', asset: 'fictional/test_hat.png'),
      PoseAccessory(slot: 'clothing_torso', asset: 'fictional/test_shirt.png'),
      PoseAccessory(slot: 'no_such_slot', asset: 'fictional/skipped.png'),
    ]);
    // Shirt sits right above the pepper body and under the eyes.
    final shirt = order.indexOf('fictional/test_shirt.png');
    expect(order[shirt - 1], '$folder/1_pepper_body.png');
    expect(order[shirt + 1], '$folder/2_eyes_brows.png');
    // Hat is the very top of the stack.
    expect(order.last, 'fictional/test_hat.png');
    // Unknown slots are skipped.
    expect(order.contains('fictional/skipped.png'), isFalse);
  });

  test('all bundled poses list layers that exist as PNG files', () {
    for (final pose in ['jalapeno_violin', 'jalapeno_piano', 'jalapeno_viola', 'jalapeno_acoustic_guitar', 'jalapeno_electric_guitar', 'jalapeno_ukulele', 'jalapeno_flute']) {
      final dir = 'assets/art/avatar_instrument/$pose';
      final m = PoseManifest.parse(
          dir, File('$dir/manifest.json').readAsStringSync());
      for (final layer in m.layers) {
        expect(File(m.layerAsset(layer)).existsSync(), isTrue,
            reason: '$pose/$layer');
      }
    }
  });

  test('standing poses of the three free characters have all layers and a frame', () {
    for (final key in ['kiwi', 'strawberry', 'jalapeno']) {
      final dir = 'assets/art/avatar_pose/${key}_standing';
      final m = PoseManifest.parse(
          dir, File('$dir/manifest.json').readAsStringSync());
      expect(m.layers.length, greaterThanOrEqualTo(6), reason: key);
      for (final layer in m.layers) {
        expect(File(m.layerAsset(layer)).existsSync(), isTrue,
            reason: '$key/$layer');
      }
      expect(m.displayBox, isNotNull, reason: key);
      // Every accessory slot points at a real layer.
      expect(m.slots.keys,
          containsAll(['behind_body', 'clothing_torso', 'shoes', 'face', 'hat']),
          reason: key);
      final order = poseDrawOrder(m, const [
        PoseAccessory(slot: 'hat', asset: 'fictional/test_hat.png')
      ]);
      expect(order.last, 'fictional/test_hat.png');
    }
  });
}
