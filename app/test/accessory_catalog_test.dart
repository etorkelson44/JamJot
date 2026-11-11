import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/widgets/accessory_catalog.dart';
import 'package:jamjot/widgets/pose_stack.dart';

void main() {
  dressedFrameTests();
  keywiOutfitTests();
  jalapenoOutfitTests();
  final json = File('assets/art/accessories/catalog.json').readAsStringSync();
  final catalog = parseAccessoryCatalog(json);
  List<AccessoryItem> released() => [
        for (final i in catalog)
          AccessoryItem(
              id: i.id, name: i.name, released: true, art: i.art, display: i.display)
      ];

  test('catalog lists the four outfit items, drawn for Ms. Straw-ccato and Keywi standing', () {
    expect(catalog.map((i) => i.id), [
      'purple_glitter_crown',
      'cat_eye_sunglasses',
      'pink_ruffle_dress',
      'lilac_platform_boots'
    ]);
    for (final i in catalog) {
      expect(i.hasArtFor('strawberry', 'standing'), isTrue, reason: i.id);
      expect(i.hasArtFor('kiwi', 'standing'), isTrue, reason: i.id);
      expect(i.hasArtFor('jalapeno', 'standing'), isTrue, reason: i.id);
      expect(i.hasArtFor('jalapeno', 'violin'), isFalse, reason: i.id);
      for (final av in ['strawberry', 'kiwi', 'jalapeno']) {
        for (final p in i.art['${av}_standing']!) {
          expect(File('${i.assetFolder(av, 'standing')}/${p.file}').existsSync(),
              isTrue,
              reason: '${i.id}/$av/${p.file}');
        }
      }
    }
  });

  test('each item has one shelf image for the Market and dressing room', () {
    for (final i in catalog) {
      expect(File(i.displayAsset).existsSync(), isTrue, reason: i.id);
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
    expect(resolveAccessories(c, ['pink_ruffle_dress'], 'jalapeno', 'violin'), isEmpty);
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

void keywiOutfitTests() {
  final catalog = parseAccessoryCatalog(
      File('assets/art/accessories/catalog.json').readAsStringSync());
  test('Keywi outfit stacks like the layered PDF: top under the face, skirt over the arms', () {
    final all = [
      for (final i in catalog)
        AccessoryItem(id: i.id, name: i.name, released: true, art: i.art, display: i.display)
    ];
    final manifest = PoseManifest.parse('assets/art/avatar_pose/kiwi_standing',
        File('assets/art/avatar_pose/kiwi_standing/manifest.json').readAsStringSync());
    final acc = resolveAccessories(all, all.map((i) => i.id), 'kiwi', 'standing');
    final order = poseDrawOrder(manifest, acc).map((a) => a.split('/').last).toList();
    int at(String f) => order.indexOf(f);
    expect(at('1_body.png'), lessThan(at('1_strapless_top.png')));
    expect(at('1_strapless_top.png'), lessThan(at('2_eyes_brows.png')));
    expect(at('3_mouth.png'), lessThan(at('sunglasses.png')));
    expect(at('4_legs_feet.png'), lessThan(at('1_boot_viewer_left.png')));
    expect(at('6_arm_viewer_right.png'), lessThan(at('2_ruffle_skirt.png')));
    expect(at('2_ruffle_skirt.png'), lessThan(at('3_sash_bow.png')));
    expect(at('3_sash_bow.png'), lessThan(at('crown.png')));
    expect(order.length, manifest.layers.length + 7);
  });
  test('kiwi dressed frame holds crown and boots', () {
    final m = jsonDecode(File('assets/art/avatar_pose/kiwi_standing/manifest.json').readAsStringSync());
    final b = (m['dressed_display_box'] as List).cast<num>();
    expect(b[1] <= 25 && b[1] + b[2] >= 975, isTrue);
  });
}

void jalapenoOutfitTests() {
  final catalog = parseAccessoryCatalog(
      File('assets/art/accessories/catalog.json').readAsStringSync());
  test('Jalapresto outfit stacks like the layered PDF: dress over the arms, left boot over the skirt, glasses and crown on top', () {
    final all = [
      for (final i in catalog)
        AccessoryItem(id: i.id, name: i.name, released: true, art: i.art, display: i.display)
    ];
    final manifest = PoseManifest.parse('assets/art/avatar_pose/jalapeno_standing',
        File('assets/art/avatar_pose/jalapeno_standing/manifest.json').readAsStringSync());
    final acc = resolveAccessories(all, all.map((i) => i.id), 'jalapeno', 'standing');
    final order = poseDrawOrder(manifest, acc).map((a) => a.split('/').last).toList();
    int at(String f) => order.indexOf(f);
    expect(at('5_legs_feet.png'), lessThan(at('2_boot_viewer_right.png')));
    expect(at('2_boot_viewer_right.png'), lessThan(at('6_arm_viewer_right.png')));
    expect(at('7_arm_viewer_left.png'), lessThan(at('2_ruffle_skirt.png')));
    expect(at('2_ruffle_skirt.png'), lessThan(at('1_strapless_top.png')));
    expect(at('1_strapless_top.png'), lessThan(at('3_sash_bow.png')));
    expect(at('3_sash_bow.png'), lessThan(at('1_boot_viewer_left.png')));
    expect(at('4_eyes_brows.png'), lessThan(at('sunglasses.png')));
    expect(at('1_boot_viewer_left.png'), lessThan(at('crown.png')));
    expect(order.length, manifest.layers.length + 7);
  });
  test('jalapeno dressed frame holds crown and boots', () {
    final m = jsonDecode(File('assets/art/avatar_pose/jalapeno_standing/manifest.json').readAsStringSync());
    final b = (m['dressed_display_box'] as List).cast<num>();
    expect(b[1] <= 72 && b[1] + b[2] >= 969, isTrue);
    expect(b[0] >= 0 && b[0] + b[2] <= 1000, isTrue);
  });
}

void dressedFrameTests() {
  test('strawberry dressed frame holds every outfit piece', () {
    final m = jsonDecode(File('assets/art/avatar_pose/strawberry_standing/manifest.json').readAsStringSync());
    final b = (m['dressed_display_box'] as List).cast<num>();
    expect(b.length, 3);
    // crown top (y 71) and boot bottoms (y 933) on the 1000px canvas
    expect(b[1] <= 71 && b[1] + b[2] >= 933, isTrue);
    expect(b[0] >= 0 && b[0] + b[2] <= 1000, isTrue);
  });
}
