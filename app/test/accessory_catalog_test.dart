import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/widgets/accessory_catalog.dart';
import 'package:jamjot/widgets/pose_stack.dart';

const starterIds = [
  'purple_glitter_crown',
  'cat_eye_sunglasses',
  'pink_ruffle_dress',
  'lilac_platform_boots'
];
const prestoIds = ['black_top_hat', 'gold_monocle', 'black_tuxedo', 'red_sneakers'];
const jalapenoPoses = [
  'violin', 'viola', 'piano', 'flute', 'cello', 'double_bass',
  'acoustic_guitar', 'electric_guitar', 'ukulele'
];

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

  test('catalog lists the four starter items then the four Presto items, with their final names', () {
    expect(catalog.map((i) => i.id), [...starterIds, ...prestoIds]);
    expect(catalog.map((i) => i.name), [
      'Dolce Diadem',
      'Crescendo Cat-Eyes',
      'Falsetto Frock',
      'Bravura Boots',
      'Tarantella Top Hat',
      'Marcato Monocle',
      'Toccata Tuxedo',
      'Legato Lace-Ups'
    ]);
    for (final i in catalog.where((i) => starterIds.contains(i.id))) {
      expect(i.hasArtFor('strawberry', 'standing'), isTrue, reason: i.id);
      expect(i.hasArtFor('kiwi', 'standing'), isTrue, reason: i.id);
      expect(i.hasArtFor('jalapeno', 'standing'), isTrue, reason: i.id);
      expect(i.hasArtFor('jalapeno', 'trumpet'), isFalse, reason: i.id);
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
    expect(resolveAccessories(c, ['pink_ruffle_dress'], 'jalapeno', 'trumpet'), isEmpty);
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
    expect(jsonDecode(json)['items'], hasLength(8));
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
  List<AccessoryItem> all() => [
        for (final i in catalog.where((i) => starterIds.contains(i.id)))
          AccessoryItem(id: i.id, name: i.name, released: true, art: i.art, display: i.display)
      ];
  List<AccessoryItem> presto() => [
        for (final i in catalog.where((i) => prestoIds.contains(i.id)))
          AccessoryItem(id: i.id, name: i.name, released: true, art: i.art, display: i.display)
      ];
  test('Presto set is drawn for Jalapresto standing and every finished instrument pose, not yet for Keywi or Ms. Straw-ccato', () {
    for (final i in catalog.where((i) => prestoIds.contains(i.id))) {
      expect(i.released, isFalse, reason: i.id);
      expect(i.hasArtFor('jalapeno', 'standing'), isTrue, reason: i.id);
      expect(i.hasArtFor('kiwi', 'standing'), isFalse, reason: i.id);
      expect(i.hasArtFor('strawberry', 'standing'), isFalse, reason: i.id);
      expect(File(i.displayAsset).existsSync(), isTrue, reason: i.id);
    }
  });
  test('Presto standing stack: sleeves, shirt and jacket over the arms, then legs over the jacket; sneakers replace the legs; monocle and hat on top', () {
    final manifest = PoseManifest.parse('assets/art/avatar_pose/jalapeno_standing',
        File('assets/art/avatar_pose/jalapeno_standing/manifest.json').readAsStringSync());
    final acc = resolveAccessories(presto(), prestoIds, 'jalapeno', 'standing');
    final order = poseDrawOrder(manifest, acc).map((a) => a.split('/').last).toList();
    int at(String f) => order.indexOf(f);
    expect(order.contains('5_legs_feet.png'), isFalse);
    expect(at('legs_under_sneakers.png'), lessThan(at('1_sneaker_flat.png')));
    expect(at('7_arm_viewer_left.png'), lessThan(at('1_sleeves.png')));
    expect(at('1_sleeves.png'), lessThan(at('2_jacket.png')));
    expect(at('2_jacket.png'), lessThan(at('3_legs_over_jacket.png')));
    expect(at('4_eyes_brows.png'), lessThan(at('monocle_lens.png')));
    expect(at('3_teeth.png'), lessThan(at('2_mustache.png')));
    expect(at('monocle_lens.png'), lessThan(at('2_mustache.png')));
    expect(at('2_mustache.png'), lessThan(at('monocle_chain.png')));
    expect(order.length, manifest.layers.length + 8);
  });
  test('every finished Jalapresto instrument pose has Presto art whose files and slots exist; jacket under the arms, sneakers replace the legs', () {
    for (final pose in jalapenoPoses) {
      final folder = 'assets/art/avatar_instrument/jalapeno_$pose';
      final manifest = PoseManifest.parse(folder, File('$folder/manifest.json').readAsStringSync());
      for (final i in catalog.where((i) => prestoIds.contains(i.id))) {
        expect(i.hasArtFor('jalapeno', pose), isTrue, reason: '${i.id} $pose');
        for (final p in i.art['jalapeno_$pose']!) {
          expect(File('${i.assetFolder('jalapeno', pose)}/${p.file}').existsSync(), isTrue,
              reason: '${i.id}/$pose/${p.file}');
          if (p.replaces != null) {
            expect(manifest.layers.contains(p.replaces), isTrue, reason: '$pose ${p.replaces}');
          } else {
            expect(manifest.slots.containsKey(p.slot), isTrue, reason: '$pose slot ${p.slot}');
          }
        }
      }
      if (pose == 'piano') continue; // piano is built from Erika's finished PDF; see its own test below
      final acc = resolveAccessories(presto(), prestoIds, 'jalapeno', pose);
      final order = poseDrawOrder(manifest, acc).map((a) => a.split('/').last).toList();
      int at(String f) => order.indexOf(f);
      expect(at('jacket.png'), greaterThan(at('1_pepper_body.png')), reason: pose);
      if (pose != 'electric_guitar' && pose != 'ukulele') {
        // legs and feet stay whole, layered behind the sneakers
        final legs = manifest.layers.firstWhere((l) => l.contains('legs_feet'));
        expect(at('$legs.png'), greaterThan(at('jacket.png')), reason: pose);
        expect(at('$legs.png'), lessThan(at('1_sneaker.png')), reason: pose);
      } else {
        expect(at('legs_under_sneakers.png'), greaterThan(at('jacket.png')), reason: pose);
      }
      expect(at('monocle_lens.png'), greaterThan(at('jacket.png')), reason: pose);
      // acoustic guitar: his crossed legs get Erika's pair of shoes as one piece
      expect(order.where((f) => f.endsWith('_sneaker.png')).length, pose == 'acoustic_guitar' ? 1 : 2, reason: pose);
      // acoustic guitar is built from Erika's layered PDF (its sleeves are her pieces); see its own test below
      if (pose != 'acoustic_guitar') expect(order.where((f) => f.startsWith('sleeve_')).length, greaterThanOrEqualTo(2), reason: pose);
    }
  });
  test('Jalapresto outfit stacks like the layered PDF: boots behind the skirt, dress over the arms, glasses and crown on top', () {
    final manifest = PoseManifest.parse('assets/art/avatar_pose/jalapeno_standing',
        File('assets/art/avatar_pose/jalapeno_standing/manifest.json').readAsStringSync());
    final acc = resolveAccessories(all(), all().map((i) => i.id), 'jalapeno', 'standing');
    final order = poseDrawOrder(manifest, acc).map((a) => a.split('/').last).toList();
    int at(String f) => order.indexOf(f);
    expect(order.contains('5_legs_feet.png'), isFalse);
    expect(at('legs_under_boots.png'), lessThan(at('2_boot_viewer_right.png')));
    expect(at('2_boot_viewer_right.png'), lessThan(at('1_boot_viewer_left.png')));
    expect(at('1_boot_viewer_left.png'), lessThan(at('6_arm_viewer_right.png')));
    expect(at('7_arm_viewer_left.png'), lessThan(at('2_ruffle_skirt.png')));
    expect(at('2_ruffle_skirt.png'), lessThan(at('1_strapless_top.png')));
    expect(at('1_strapless_top.png'), lessThan(at('3_sash_bow.png')));
    expect(at('4_eyes_brows.png'), lessThan(at('sunglasses.png')));
    expect(at('3_sash_bow.png'), lessThan(at('crown.png')));
    expect(order.length, manifest.layers.length + 7);
  });
  test('every finished Jalapresto instrument pose is dressed: trimmed legs, boots, then skirt, all before the arms and instrument', () {
    for (final pose in ['violin', 'viola', 'piano', 'flute', 'cello', 'double_bass', 'acoustic_guitar', 'electric_guitar', 'ukulele']) {
      final folder = 'assets/art/avatar_instrument/jalapeno_$pose';
      final manifest = PoseManifest.parse(
          folder, File('$folder/manifest.json').readAsStringSync());
      for (final i in catalog.where((i) => starterIds.contains(i.id))) {
        expect(i.hasArtFor('jalapeno', pose), isTrue, reason: '${i.id} $pose');
        for (final p in i.art['jalapeno_$pose']!) {
          expect(File('${i.assetFolder('jalapeno', pose)}/${p.file}').existsSync(), isTrue,
              reason: '${i.id}/$pose/${p.file}');
          if (p.replaces != null) {
            expect(manifest.layers.contains(p.replaces), isTrue, reason: '$pose ${p.replaces}');
          } else {
            expect(manifest.slots.containsKey(p.slot), isTrue, reason: '$pose slot ${p.slot}');
          }
        }
      }
      final acc = resolveAccessories(all(), all().map((i) => i.id), 'jalapeno', pose);
      final order = poseDrawOrder(manifest, acc).map((a) => a.split('/').last).toList();
      int at(String f) => order.indexOf(f);
      final legs = manifest.slots['clothing_lower']!.layer;
      expect(order.contains('$legs.png'), isFalse, reason: pose);
      expect(at('legs_under_boots.png'), lessThan(at('2_boot_viewer_right.png')), reason: pose);
      expect(at('1_boot_viewer_left.png'), lessThan(at('2_ruffle_skirt.png')), reason: pose);
      expect(at('2_ruffle_skirt.png'), lessThan(at('1_strapless_top.png')), reason: pose);
      expect(at('sunglasses.png'), lessThan(at('crown.png')), reason: pose);
      expect(order.length, manifest.layers.length + 7, reason: pose);
    }
  });
  test('Presto piano (from Erika\'s finished PDF): jacket under the keyboard, her hands on top, her legs behind her red shoes', () {
    final folder = 'assets/art/avatar_instrument/jalapeno_piano';
    final manifest = PoseManifest.parse(folder, File('$folder/manifest.json').readAsStringSync());
    final acc = resolveAccessories(presto(), prestoIds, 'jalapeno', 'piano');
    final order = poseDrawOrder(manifest, acc).map((a) => a.split('/').last).toList();
    int at(String f) => order.indexOf(f);
    // the plain arms and keyboard are swapped for hers
    for (final gone in ['7_arm_viewer_left.png', '8_arm_viewer_right.png', '6_keyboard.png', '5_legs_feet.png']) {
      expect(order.contains(gone), isFalse, reason: gone);
    }
    expect(at('1_sleeve_back_left.png'), lessThan(at('1_pepper_body.png')));
    expect(at('1_pepper_body.png'), lessThan(at('5_jacket_front.png')));
    expect(at('5_jacket_front.png'), lessThan(at('keyboard_lowered.png')));
    expect(at('legs.png'), lessThan(at('shoe_left.png')));
    expect(at('shoe_right.png'), lessThan(at('keyboard_lowered.png')));
    for (final h in ['hand_1.png', 'hand_5.png']) {
      expect(at(h), greaterThan(at('keyboard_lowered.png')), reason: h);
    }
    expect(at('monocle_lens.png'), lessThan(at('2_mustache.png')));
    expect(at('2_mustache.png'), lessThan(at('monocle_chain.png')));
  });
  test('Presto acoustic guitar (from Erika\'s layered PDF): fret arm behind the body, her guitar, then fingers, strum arm and sleeves on top', () {
    final folder = 'assets/art/avatar_instrument/jalapeno_acoustic_guitar';
    final manifest = PoseManifest.parse(folder, File('$folder/manifest.json').readAsStringSync());
    final acc = resolveAccessories(presto(), prestoIds, 'jalapeno', 'acoustic_guitar');
    final order = poseDrawOrder(manifest, acc).map((a) => a.split('/').last).toList();
    int at(String f) => order.indexOf(f);
    for (final gone in ['6_fret_arm.png', '7_guitar.png', '8_fingertips.png', '9_strum_arm_hand.png']) {
      expect(order.contains(gone), isFalse, reason: gone);
    }
    expect(at('1_fret_arm.png'), lessThan(at('2_fret_sleeve.png')));
    expect(at('2_fret_sleeve.png'), lessThan(at('1_pepper_body.png')));
    expect(at('jacket.png'), lessThan(at('guitar.png')));
    expect(at('1_sneaker.png'), lessThan(at('guitar.png')));
    expect(at('guitar.png'), lessThan(at('fingertips.png')));
    expect(at('fingertips.png'), lessThan(at('strum_arm_hand.png')));
    expect(at('strum_arm_hand.png'), lessThan(at('4_strum_forearm_sleeve.png')));
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
