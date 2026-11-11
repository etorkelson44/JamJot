import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/widgets/accessory_catalog.dart';
import 'package:jamjot/widgets/pose_stack.dart';

void main() {
  final json = File('assets/art/accessories/catalog.json').readAsStringSync();
  final catalog = parseAccessoryCatalog(json);
  List<AccessoryItem> released() => [
        for (final i in catalog)
          AccessoryItem(
              id: i.id, name: i.name, released: true, art: i.art)
      ];

  test('catalog lists the four strawberry outfit items, all drawn for her standing pose', () {
    expect(catalog.map((i) => i.id), [
      'purple_glitter_crown',
      'cat_eye_sunglasses',
      'pink_ruffle_dress',
      'lilac_platform_boots'
    ]);
    for (final i in catalog) {
      expect(i.hasArtFor('strawberry', 'standing'), isTrue, reason: i.id);
      expect(i.hasArtFor('kiwi', 'standing'), isFalse, reason: i.id);
      for (final p in i.art['strawberry_standing']!) {
        expect(File('${i.assetFolder('strawberry', 'standing')}/${p.file}').existsSync(),
            isTrue,
            reason: '${i.id}/${p.file}');
      }
    }
  });

  test('every item is wired in but not wearable yet', () {
    expect(catalog.every((i) => !i.released), isTrue);
    expect(
        resolveAccessories(catalog, catalog.map((i) => i.id), 'strawberry', 'standing'),
        isEmpty);
  });

  test('once released, an item is hidden for an avatar or pose it has no art for', () {
    final c = released();
    expect(resolveAccessories(c, ['pink_ruffle_dress'], 'kiwi', 'standing'), isEmpty);
    expect(resolveAccessories(c, ['pink_ruffle_dress'], 'strawberry', 'violin'), isEmpty);
    expect(resolveAccessories(c, ['no_such_item'], 'strawberry', 'standing'), isEmpty);
  });

  test('the dress is one item of three layers in order: top, skirt, sash with bow', () {
    final r = resolveAccessories(released(), ['pink_ruffle_dress'], 'strawberry', 'standing');
    expect(r.map((a) => a.asset.split('/').last),
        ['1_strapless_top.png', '2_ruffle_skirt.png', '3_sash_bow.png']);
    expect(r.every((a) => a.slot == 'clothing_torso'), isTrue);
  });

  test('a full outfit draws legs, boots, dress, arms, then glasses and crown', () {
    final manifest = PoseManifest.parse('assets/art/avatar_pose/strawberry_standing',
        File('assets/art/avatar_pose/strawberry_standing/manifest.json').readAsStringSync());
    final acc = resolveAccessories(
        released(),
        ['purple_glitter_crown', 'cat_eye_sunglasses', 'pink_ruffle_dress', 'lilac_platform_boots'],
        'strawberry',
        'standing');
    final order = poseDrawOrder(manifest, acc).map((a) => a.split('/').last).toList();
    int at(String f) => order.indexOf(f);
    expect(at('3_legs_feet.png'), lessThan(at('1_boot_viewer_left.png')));
    expect(at('2_boot_viewer_right.png'), lessThan(at('1_strapless_top.png')));
    expect(at('3_sash_bow.png'), lessThan(at('4_arm_viewer_right.png')));
    expect(at('5_arm_viewer_left.png'), lessThan(at('6_eyes_lashes.png')));
    expect(at('6_eyes_lashes.png'), lessThan(at('sunglasses.png')));
    expect(at('sunglasses.png'), lessThan(at('crown.png')));
    expect(order.length, manifest.layers.length + 7);
  });

  test('catalog json parses with the expected keys', () {
    expect(jsonDecode(json)['items'], hasLength(4));
  });
}
