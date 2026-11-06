import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';

/// Native platforms: plays nothing for the synthesized web effects.
void playSound(String name) {}

const _scale = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21];

/// One "Retro coin 4" blip per coin, [delaysMs] after now, each a little
/// higher than the last. Same bundled sound as the web build.
void playCoinPings(List<int> delaysMs) {
  for (var i = 0; i < delaysMs.length && i < 24; i++) {
    final rate = _rate(_scale[i < _scale.length ? i : _scale.length - 1]);
    Timer(Duration(milliseconds: delaysMs[i]), () => unawaited(_ping(rate)));
  }
}

double _rate(int semitones) => math.pow(2, semitones / 12).toDouble();

Future<void> _ping(double rate) async {
  final player = AudioPlayer();
  try {
    await player.setPlaybackRate(rate);
    await player.play(AssetSource('audio/coin_retro.mp3'), volume: .55);
    await player.onPlayerComplete.first.timeout(const Duration(seconds: 3));
  } catch (_) {
    /* Sound is optional; coins remain earned if playback fails. */
  } finally {
    try {
      await player.dispose();
    } catch (_) {}
  }
}
