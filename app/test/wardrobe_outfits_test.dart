import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/state/wardrobe.dart';

void main() {
  test('outfits from a student record keep only known pieces and drop empty avatars', () {
    final got = parseOutfits({
      'kiwi': ['sugar_shrub_shako', 'retired_piece'],
      'jalapeno': ['retired_piece'],
      'strawberry': 'not a list',
      7: ['sugar_shrub_shako'],
    }, {'sugar_shrub_shako'});
    expect(got, {
      'kiwi': ['sugar_shrub_shako']
    });
  });
}
