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
const keywiSetIds = ['ballad_bucket_hat', 'fermata_frames', 'tenuto_tee', 'jazzy_joggers', 'serenade_sandals'];
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
    expect(catalog.map((i) => i.id), [...starterIds, ...prestoIds, 'sugar_shrub_shako', ...keywiSetIds]);
    expect(catalog.map((i) => i.name), [
      'Dolce Diadem',
      'Crescendo Cat-Eyes',
      'Falsetto Frock',
      'Bravura Boots',
      'Tarantella Top Hat',
      'Marcato Monocle',
      'Toccata Tuxedo',
      'Legato Lace-Ups',
      'Sugar Shrub Shako',
      'Ballad Bucket Hat',
      'Fermata Frames',
      'Tenuto Tee',
      'Jazzy Joggers',
      'Serenade Sandals'
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

  test('every item for sale is wired in but not wearable yet; only the free shako is live', () {
    expect(catalog.where((i) => i.released).map((i) => i.id), ['sugar_shrub_shako']);
    expect(catalog.where((i) => !i.free).every((i) => !i.released), isTrue);
    expect(
        resolveAccessories(catalog, catalog.map((i) => i.id), 'strawberry', 'standing')
            .map((a) => a.asset.split('/').last),
        ['shako.png']);
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
    expect(jsonDecode(json)['items'], hasLength(14));
  });
}

void keywiOutfitTests() {
  final catalog = parseAccessoryCatalog(
      File('assets/art/accessories/catalog.json').readAsStringSync());
  test('Keywi outfit stacks like the layered PDF: top under the face, skirt over the arms', () {
    final all = [
      for (final i in catalog.where((i) => starterIds.contains(i.id)))
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
  test('Presto set is drawn for Jalapresto standing and every finished instrument pose, and for Keywi and Ms. Straw-ccato standing', () {
    for (final i in catalog.where((i) => prestoIds.contains(i.id))) {
      expect(i.released, isFalse, reason: i.id);
      expect(i.hasArtFor('jalapeno', 'standing'), isTrue, reason: i.id);
      expect(i.hasArtFor('kiwi', 'standing'), isTrue, reason: i.id);
      expect(i.hasArtFor('strawberry', 'standing'), isTrue, reason: i.id);
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
      // legs and feet stay whole, layered behind the sneakers (crossed-leg poses use Erika's shoe pair as one piece)
      final crossed = ['acoustic_guitar', 'electric_guitar', 'ukulele'].contains(pose);
      final legs = manifest.layers.firstWhere((l) => l.contains('legs_feet'));
      expect(at('$legs.png'), greaterThan(at('jacket.png')), reason: pose);
      expect(at('$legs.png'), lessThan(at('1_sneaker.png')), reason: pose);
      expect(at('monocle_lens.png'), greaterThan(at('jacket.png')), reason: pose);
      // acoustic guitar: his crossed legs get Erika's pair of shoes as one piece
      expect(order.where((f) => f.endsWith('_sneaker.png')).length, crossed ? 1 : 2, reason: pose);
      // acoustic guitar is built from Erika's layered PDF (its sleeves are her pieces); see its own test below
      if (!crossed) expect(order.where((f) => f.startsWith('sleeve_')).length, greaterThanOrEqualTo(2), reason: pose);
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
  test('Presto acoustic and electric guitar (from Erika\'s layered PDF): fret arm behind the body, the moved guitar, then fingers, strum arm and sleeves on top', () {
   for (final gp in ['acoustic_guitar', 'electric_guitar', 'ukulele']) {
    final folder = 'assets/art/avatar_instrument/jalapeno_$gp';
    final manifest = PoseManifest.parse(folder, File('$folder/manifest.json').readAsStringSync());
    final acc = resolveAccessories(presto(), prestoIds, 'jalapeno', gp);
    final order = poseDrawOrder(manifest, acc).map((a) => a.split('/').last).toList();
    int at(String f) => order.indexOf(f);
    for (final gone in ['6_fret_arm.png', '7_guitar.png', '7_ukulele.png', '8_fingertips.png', '9_strum_arm_hand.png']) {
      expect(order.contains(gone), isFalse, reason: gone);
    }
    expect(at('1_fret_arm.png'), lessThan(at('2_fret_sleeve.png')));
    expect(at('2_fret_sleeve.png'), lessThan(at('1_pepper_body.png')));
    expect(at('jacket.png'), lessThan(at('guitar.png')));
    expect(at('1_sneaker.png'), lessThan(at('guitar.png')));
    expect(at('guitar.png'), lessThan(at('fingertips.png')));
    expect(at('fingertips.png'), lessThan(at('strum_arm_hand.png')));
    expect(at('strum_arm_hand.png'), lessThan(at('4_strum_forearm_sleeve.png')));
   }
  });
  test('Presto set on Keywi and Ms. Straw-ccato (their regular poses): files exist and layer as in Erika\'s PDFs', () {
    for (final tag in ['kiwi_standing', 'strawberry_standing']) {
      final folder = 'assets/art/avatar_pose/$tag';
      final manifest = PoseManifest.parse(folder, File('$folder/manifest.json').readAsStringSync());
      for (final i in catalog.where((i) => prestoIds.contains(i.id))) {
        final pieces = i.art[tag];
        expect(pieces, isNotNull, reason: '${i.id} $tag');
        for (final p in pieces!) {
          expect(File('assets/art/accessories/${i.id}/$tag/${p.file}').existsSync(), isTrue, reason: '${i.id} $tag ${p.file}');
        }
      }
      final avatar = tag.split('_').first;
      final acc = resolveAccessories(presto(), prestoIds, avatar, 'standing');
      final order = poseDrawOrder(manifest, acc).map((a) => a.split('/').last).toList();
      int at(String f) => order.indexOf(f);
      if (avatar == 'kiwi') {
        expect(at('6_arm_viewer_right.png'), lessThan(at('2_jacket.png')));
        expect(at('2_jacket.png'), lessThan(at('3_mouth_over_jacket.png')));
        expect(at('2_jacket.png'), lessThan(at('5_sleeve_viewer_left.png')));
      } else {
        expect(at('2_arm_viewer_right_behind.png'), lessThan(at('1_body.png')));
        expect(order.contains('4_arm_viewer_right.png'), isFalse);
        expect(at('3_shirt.png'), lessThan(at('4_arm_viewer_left.png')));
        expect(at('5_sleeve_viewer_left.png'), lessThan(at('monocle.png')));
        expect(at('monocle.png'), lessThan(at('6_jacket.png')));
      }
    }
  });
  test('Sugar Shrub Shako (JJ-061-C): a free, released hat with art for every finished pose and its own taller frame', () {
    final shako = catalog.firstWhere((i) => i.id == 'sugar_shrub_shako');
    expect(shako.name, 'Sugar Shrub Shako');
    expect(shako.released, isTrue);
    expect(shako.free, isTrue);
    expect(freeAccessoryIds(catalog), {'sugar_shrub_shako'});
    expect(File(shako.displayAsset).existsSync(), isTrue);
    final tags = [
      'kiwi_standing',
      'strawberry_standing',
      'jalapeno_standing',
      for (final p in jalapenoPoses) 'jalapeno_$p'
    ];
    for (final tag in tags) {
      final avatar = tag.split('_').first;
      final pose = tag.substring(avatar.length + 1);
      expect(shako.hasArtFor(avatar, pose), isTrue, reason: tag);
      for (final p in shako.art[tag]!) {
        expect(File('assets/art/accessories/sugar_shrub_shako/$tag/${p.file}').existsSync(), isTrue, reason: tag);
      }
      // The feather rises above the canvas, so the frame starts above it.
      final frame = accessoryFrame(catalog, ['sugar_shrub_shako'], avatar, pose);
      expect(frame, isNotNull, reason: tag);
      expect(frame![1], lessThan(0), reason: tag);
      final acc = resolveAccessories(catalog, ['sugar_shrub_shako'], avatar, pose);
      expect(acc.single.overflowTop, 200, reason: tag);
    }
    // No other item asks for a bigger frame, and unreleased items never do.
    expect(accessoryFrame(catalog, prestoIds, 'jalapeno', 'standing'), isNull);
    // An avatar or pose with no fitted art falls back to the plain pose.
    expect(resolveAccessories(catalog, ['sugar_shrub_shako'], 'kiwi', 'violin'), isEmpty);
    expect(accessoryFrame(catalog, ['sugar_shrub_shako'], 'kiwi', 'violin'), isNull);
  });
  test('Sugar Shrub Shako on the double bass sits behind the bass, so the scroll shows in front of the hat', () {
    final folder = 'assets/art/avatar_instrument/jalapeno_double_bass';
    final manifest = PoseManifest.parse(folder, File('$folder/manifest.json').readAsStringSync());
    final acc = resolveAccessories(catalog, ['sugar_shrub_shako'], 'jalapeno', 'double_bass');
    final order = poseDrawOrder(manifest, acc).map((a) => a.split('/').last).toList();
    final bass = manifest.layers.firstWhere((l) => l.contains('double_bass'));
    expect(order.indexOf('shako.png'), greaterThan(order.indexOf('4_mustache.png')));
    expect(order.indexOf('shako.png'), lessThan(order.indexOf('$bass.png')));
  });
  test('Keywi\'s set: off for now; joggers and sandals fit his normal legs and all of Presto\'s poses', () {
    final c = [
      for (final i in catalog)
        AccessoryItem(
            id: i.id, name: i.name, released: true, art: i.art, display: i.display, kind: i.kind,
            overflowTop: i.overflowTop, overflowBottom: i.overflowBottom, frames: i.frames)
    ];
    final folder = 'assets/art/avatar_pose/kiwi_standing';
    final manifest = PoseManifest.parse(folder, File('$folder/manifest.json').readAsStringSync());
    List<String> order(List<String> ids) =>
        poseDrawOrder(manifest, resolveAccessories(c, ids, 'kiwi', 'standing')).map((a) => a.split('/').last).toList();
    const prestoPoses = ['standing', 'violin', 'viola', 'piano', 'flute', 'acoustic_guitar', 'electric_guitar', 'ukulele', 'cello', 'double_bass'];
    for (final i in catalog.where((i) => keywiSetIds.contains(i.id))) {
      expect(i.released, isFalse, reason: i.id);
      expect(File(i.displayAsset).existsSync(), isTrue, reason: i.id);
      for (final e in i.art.entries) {
        for (final p in e.value) {
          expect(File('assets/art/accessories/${i.id}/${e.key}/${p.file}').existsSync(), isTrue, reason: '${e.key}/${p.file}');
        }
      }
      // Ms. Straw-ccato falls back to her plain pose until her art arrives.
      expect(resolveAccessories(c, [i.id], 'strawberry', 'standing'), isEmpty, reason: i.id);
      final onPresto = i.id == 'jazzy_joggers' || i.id == 'serenade_sandals';
      for (final pose in prestoPoses) {
        expect(resolveAccessories(c, [i.id], 'jalapeno', pose).isNotEmpty, onPresto, reason: '${i.id} $pose');
      }
    }
    // Hat and glasses leave his body alone.
    var o = order(['ballad_bucket_hat', 'fermata_frames']);
    expect(o, containsAll(['4_legs_feet.png', '5_arm_viewer_left.png', '6_arm_viewer_right.png', 'hat.png', 'frames.png']));
    // Tee: lower arms under the tee; legs unchanged.
    o = order(['tenuto_tee']);
    expect(o.contains('5_arm_viewer_left.png'), isFalse);
    expect(o.indexOf('arm_viewer_right.png'), lessThan(o.indexOf('tee.png')));
    expect(o.contains('4_legs_feet.png'), isTrue);
    // Sandals sit on his regular feet, with or without the joggers: soles under, straps over.
    for (final ids in [['serenade_sandals'], ['jazzy_joggers', 'serenade_sandals', 'tenuto_tee']]) {
      o = order(ids);
      final legs = ids.contains('jazzy_joggers') ? 'legs.png' : '4_legs_feet.png';
      expect(o.indexOf('soles.png'), lessThan(o.indexOf(legs)));
      expect(o.indexOf(legs), lessThan(o.indexOf('straps.png')));
    }
    // Joggers: legs trimmed above the cuffs, joggers over the tee, tuxedo over the joggers; normal height, so no bigger frame.
    expect(o.contains('4_legs_feet.png'), isFalse);
    expect(o.indexOf('tee.png'), lessThan(o.indexOf('joggers.png')));
    o = order(['black_tuxedo', 'jazzy_joggers']);
    expect(o.indexOf('joggers.png'), lessThan(o.indexOf('2_jacket.png')));
    expect(accessoryFrame(c, ['jazzy_joggers', 'tenuto_tee', 'serenade_sandals'], 'kiwi', 'standing'), isNull);
    // Pants over boots: with the joggers the Bravura Boots use the version hidden above the cuffs; other shoes are unchanged.
    o = order(['lilac_platform_boots']);
    expect(o, containsAll(['1_boot_viewer_left.png', '2_boot_viewer_right.png']));
    o = order(['lilac_platform_boots', 'jazzy_joggers']);
    expect(o, containsAll(['1_boot_viewer_left_under_joggers.png', '2_boot_viewer_right_under_joggers.png']));
    expect(o.contains('1_boot_viewer_left.png'), isFalse);
    expect(o.indexOf('2_boot_viewer_right_under_joggers.png'), lessThan(o.indexOf('joggers.png')));
    expect(order(['red_sneakers', 'jazzy_joggers']).contains('sneakers.png'), isTrue);
  });
  test('Presto in the joggers and sandals: crossed legs layer leg, foot and sandal; other poses trim the legs', () {
    final c = [
      for (final i in catalog)
        AccessoryItem(id: i.id, name: i.name, released: true, art: i.art, display: i.display, kind: i.kind,
            overflowTop: i.overflowTop, overflowBottom: i.overflowBottom, frames: i.frames)
    ];
    List<String> order(String folder, String pose, List<String> ids) {
      final m = PoseManifest.parse(folder, File('$folder/manifest.json').readAsStringSync());
      return poseDrawOrder(m, resolveAccessories(c, ids, 'jalapeno', pose)).map((a) => a.split('/').last).toList();
    }
    for (final e in {'standing': 'assets/art/avatar_pose/jalapeno_standing', 'ukulele': 'assets/art/avatar_instrument/jalapeno_ukulele'}.entries) {
      var o = order(e.value, e.key, ['serenade_sandals']);
      expect(o.indexOf('soles.png'), lessThan(o.indexOf('5_legs_feet.png')));
      expect(o.indexOf('5_legs_feet.png'), lessThan(o.indexOf('straps.png')));
      o = order(e.value, e.key, ['serenade_sandals', 'jazzy_joggers']);
      final seq = ['sole_flat.png', '5_legs_feet.png', 'strap_flat.png', 'back.png', 'sole_tiptoe.png', 'foot.png', 'strap_tiptoe.png', 'front.png'];
      for (var i = 0; i + 1 < seq.length; i++) {
        expect(o.indexOf(seq[i]), greaterThanOrEqualTo(0), reason: '${e.key} ${seq[i]}');
        expect(o.indexOf(seq[i]), lessThan(o.indexOf(seq[i + 1])), reason: '${e.key} ${seq[i]} < ${seq[i + 1]}');
      }
      expect(o.contains('soles.png'), isFalse);
      // The crossed foot is not drawn over another shoe.
      expect(order(e.value, e.key, ['red_sneakers', 'jazzy_joggers']).contains('foot.png'), isFalse);
    }
    // Under the instrument.
    var o = order('assets/art/avatar_instrument/jalapeno_ukulele', 'ukulele', ['jazzy_joggers']);
    expect(o.indexOf('front.png'), lessThan(o.indexOf('7_ukulele.png')));
    for (final e in {'violin': '3_legs_feet', 'flute': '5_legs_feet', 'cello': '5_legs_feet'}.entries) {
      o = order('assets/art/avatar_instrument/jalapeno_${e.key}', e.key, ['jazzy_joggers', 'serenade_sandals']);
      expect(o.contains('${e.value}.png'), isFalse, reason: e.key);
      expect(o.indexOf('soles.png'), lessThan(o.indexOf('legs.png')), reason: e.key);
      expect(o.indexOf('legs.png'), lessThan(o.indexOf('straps.png')), reason: e.key);
      expect(o.indexOf('straps.png'), lessThan(o.indexOf('joggers.png')), reason: e.key);
    }
  });
  test('dress rule: the Falsetto Frock is never worn with a top or a bottom, on any avatar', () {
    final c = [
      for (final i in catalog)
        AccessoryItem(
            id: i.id, name: i.name, released: true, art: i.art, display: i.display, kind: i.kind,
            overflowTop: i.overflowTop, overflowBottom: i.overflowBottom, frames: i.frames)
    ];
    String kind(String id) => catalog.firstWhere((i) => i.id == id).kind;
    expect(kind('pink_ruffle_dress'), 'dress');
    expect(kind('black_tuxedo'), 'top');
    expect(kind('tenuto_tee'), 'top');
    expect(kind('jazzy_joggers'), 'bottom');
    // Putting the frock on takes off shirts and pants, and keeps hats, glasses and shoes.
    expect(outfitConflicts(c, 'pink_ruffle_dress', ['tenuto_tee', 'jazzy_joggers', 'black_tuxedo', 'ballad_bucket_hat', 'red_sneakers']),
        ['tenuto_tee', 'jazzy_joggers', 'black_tuxedo']);
    // Putting a shirt or pants on takes the frock off, and nothing else.
    expect(outfitConflicts(c, 'jazzy_joggers', ['pink_ruffle_dress', 'tenuto_tee', 'gold_monocle']), ['pink_ruffle_dress']);
    expect(outfitConflicts(c, 'black_tuxedo', ['pink_ruffle_dress']), ['pink_ruffle_dress']);
    expect(outfitConflicts(c, 'tenuto_tee', ['jazzy_joggers', 'black_tuxedo']), isEmpty);
    expect(outfitConflicts(c, 'sugar_shrub_shako', ['pink_ruffle_dress', 'jazzy_joggers']), isEmpty);
    // An outfit saved with both never draws both: the frock wins, on every avatar.
    for (final avatar in ['kiwi', 'strawberry', 'jalapeno']) {
      final drawn = resolveAccessories(c, ['black_tuxedo', 'tenuto_tee', 'jazzy_joggers', 'pink_ruffle_dress', 'red_sneakers'], avatar, 'standing');
      expect(drawn.any((a) => a.asset.contains('pink_ruffle_dress')), isTrue, reason: avatar);
      expect(drawn.any((a) => a.asset.contains('red_sneakers')), isTrue, reason: avatar);
      for (final hidden in ['black_tuxedo', 'tenuto_tee', 'jazzy_joggers']) {
        expect(drawn.any((a) => a.asset.contains(hidden)), isFalse, reason: '$avatar $hidden');
      }
    }
    // Shoes go back to his regular foot height when the frock hides the joggers.
    final kw = resolveAccessories(c, ['jazzy_joggers', 'pink_ruffle_dress', 'red_sneakers'], 'kiwi', 'standing');
    expect(kw.any((a) => a.asset.contains('_with_joggers')), isFalse);
    expect(accessoryFrame(c, ['jazzy_joggers', 'pink_ruffle_dress'], 'kiwi', 'standing'), isNull);
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
