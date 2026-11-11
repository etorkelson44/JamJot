import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/models/caregiver_label.dart';

void main() {
  group('suggestKnownAs (JJ-054-C)', () {
    test('uses the relationship chip as a starting suggestion', () {
      expect(suggestKnownAs('Dad'), 'Dad');
      expect(suggestKnownAs('Grandma'), 'Grandma');
    });
    test('leaves the box empty when the chip is not a name', () {
      expect(suggestKnownAs('Nanny / sitter'), '');
      expect(suggestKnownAs(''), '');
    });
  });

  group('caregiverRoleSuffix', () {
    test('adds the relationship after the name', () {
      expect(caregiverRoleSuffix('Grandpa Joe', 'Grandpa'), ' • Grandpa');
    });
    test('hides a relationship that only repeats the name', () {
      expect(caregiverRoleSuffix('Dad', 'Dad'), '');
      expect(caregiverRoleSuffix('dad', 'Dad'), '');
    });
    test('is empty when there is no relationship', () {
      expect(caregiverRoleSuffix('Mom', ''), '');
      expect(caregiverRoleSuffix('Mom', '  '), '');
    });
  });
}
