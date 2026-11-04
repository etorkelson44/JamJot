import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Coin rewards share the same bundled sound on native platforms and web.
void playSound(String name) {
  if (name == 'coinDrop') unawaited(_coinDrop());
}

Future<void> _coinDrop() async {
  final player = AudioPlayer();
  try {
    await player.play(AssetSource('audio/coin_drop.wav'), volume: .5);
    await player.onPlayerComplete.first.timeout(const Duration(seconds: 5));
  } catch (_) {
    /* Sound is optional; coins remain earned if playback fails. */
  } finally {
    try {
      await player.dispose();
    } catch (_) {}
  }
}
