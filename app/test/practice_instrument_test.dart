import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/state/app_state.dart';

// Fictional data only.
void main() {
  sharedDaysTests();
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

void sharedDaysTests() {
  test('sharedDaysCount: any vs every instrument', () {
    // Mon: piano 15 (goal 15) only; Tue: both; Wed: violin 5 only (misses).
    final secs = {
      'mon': {'piano': 15 * 60},
      'tue': {'piano': 15 * 60, 'violin': 20 * 60},
      'wed': {'violin': 5 * 60},
    };
    final goals = {'piano': 15, 'violin': 20};
    expect(sharedDaysCount(secs, goals, all: false), 2);
    expect(sharedDaysCount(secs, goals, all: true), 1);
    expect(sharedDaysCount({}, goals, all: true), 0);
    expect(sharedDaysCount(secs, {}, all: false), 0);
  });
}
