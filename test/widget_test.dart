import 'package:flutter_test/flutter_test.dart';

import 'package:jamjot/theme/jamjot_theme.dart';

void main() {
  test('JamJot theme builds', () {
    final theme = buildJamJotTheme();
    expect(theme.scaffoldBackgroundColor, JamJotColors.cream);
  });
}
