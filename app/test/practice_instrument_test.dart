import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/state/app_state.dart';

// Fictional data only.
void main() {
  final kid = {'instruments': ['Piano', 'Violin']};

  test('practiceInstrumentFor: chosen tab, else first, else null', () {
    expect(practiceInstrumentFor(kid, 'violin'), 'Violin');
    expect(practiceInstrumentFor(kid, 'Flute'), 'Piano');
    expect(practiceInstrumentFor(kid, null), 'Piano');
    expect(practiceInstrumentFor({'instruments': []}, 'Piano'), isNull);
  });

  test('belongsToInstrument: no filter matches all; null rows are the first instrument', () {
    expect(belongsToInstrument('Violin', null, 'Piano'), isTrue);
    expect(belongsToInstrument('violin', 'Violin', 'Piano'), isTrue);
    expect(belongsToInstrument('Piano', 'Violin', 'Piano'), isFalse);
    expect(belongsToInstrument(null, 'Piano', 'Piano'), isTrue);
    expect(belongsToInstrument(null, 'Violin', 'Piano'), isFalse);
  });
}
