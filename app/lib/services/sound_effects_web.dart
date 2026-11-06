import 'dart:js_interop';

@JS('jjSound')
external void _jjSound(JSString name);

@JS('jjCoinPings')
external void _jjCoinPings(JSString delaysCsv);

/// Plays one of the little synthesized effects defined in index.html:
/// 'coin', 'cheer', 'fanfare', 'pop'.
void playSound(String name) {
  try {
    _jjSound(name.toJS);
  } catch (_) {/* sounds are a treat, never a crash */}
}

/// One "Retro coin 4" blip per coin, [delaysMs] after now (see coin_drop.js).
void playCoinPings(List<int> delaysMs) {
  try {
    _jjCoinPings(delaysMs.join(',').toJS);
  } catch (_) {/* sounds are a treat, never a crash */}
}
