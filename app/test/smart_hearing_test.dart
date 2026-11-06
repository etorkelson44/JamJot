import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/services/smart_listen.dart';

SmartHearing _hear({
  double speech = 0,
  double music = 0,
  double instrument = 0,
  double clap = 0,
  int impulses = 0,
}) =>
    SmartHearing(
      ready: true,
      state: 'on',
      speech: speech,
      music: music,
      instrument: instrument,
      clap: clap,
      impulses: impulses,
    );

void main() {
  test('talking alone is still speech-only and does not count', () {
    final h = _hear(speech: 0.7);
    expect(h.speechOnly, isTrue);
    expect(h.clapAndVoice, isFalse);
  });

  test('naming notes while clapping counts even if the model misses the clap',
      () {
    final h = _hear(speech: 0.7, clap: 0.02, impulses: 3);
    expect(h.clapAndVoice, isTrue);
    expect(h.speechOnly, isFalse);
    expect(h.label, 'clap & count!');
  });

  test('one sharp hit plus a faint model clap score counts with a voice', () {
    final h = _hear(speech: 0.6, clap: 0.04, impulses: 1);
    expect(h.clapAndVoice, isTrue);
    expect(h.speechOnly, isFalse);
  });

  test('a single stray hit with no clap score is not enough', () {
    final h = _hear(speech: 0.6, clap: 0.0, impulses: 1);
    expect(h.clapAndVoice, isFalse);
    expect(h.speechOnly, isTrue);
  });

  test('model-recognised clap with voice still counts (existing rule)', () {
    final h = _hear(speech: 0.5, clap: 0.12);
    expect(h.clapAndVoice, isTrue);
    expect(h.speechOnly, isFalse);
  });
}
