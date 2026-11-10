import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/widgets/letter_avatar.dart';

void main() {
  test('Keywi is the default for unset, empty or unknown avatars', () {
    expect(defaultAvatarKey, 'kiwi');
    expect(studentAvatarKey(null), 'kiwi');
    expect(studentAvatarKey(''), 'kiwi');
    expect(studentAvatarKey('sonatina'), 'kiwi');
    expect(studentAvatarKey('not_a_character'), 'kiwi');
  });

  test('a known worn avatar is kept', () {
    expect(studentAvatarKey('strawberry'), 'strawberry');
    expect(studentAvatarKey('jalapeno'), 'jalapeno');
    expect(studentAvatarKey('kiwi'), 'kiwi');
  });

  test('clearing an avatar is never allowed', () {
    expect(isWearableAvatar(null), isFalse);
    expect(isWearableAvatar(''), isFalse);
    expect(isWearableAvatar('sonatina'), isFalse);
    expect(isWearableAvatar('kiwi'), isTrue);
  });
}
