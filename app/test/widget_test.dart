import 'package:flutter_test/flutter_test.dart';

import 'package:jamjot/theme/jamjot_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('JamJot themes build for both skins', () {
    // Grown-up skin is the default (Calm Studio); kids get the Jam Stand.
    expect(buildJamJotTheme().scaffoldBackgroundColor, CalmStudio.base);
    expect(buildJamJotTheme(JamJotSkin.grownup).scaffoldBackgroundColor,
        CalmStudio.base);
    expect(buildJamJotTheme(JamJotSkin.kid).scaffoldBackgroundColor,
        JamStand.paper);
  });
}
