import 'dart:js_interop';

@JS('jjSound')
external void _jjSound(JSString name);

/// Plays one of the little synthesized effects defined in index.html:
/// 'coin', 'cheer', 'fanfare', 'pop'.
void playSound(String name) {
  try {
    _jjSound(name.toJS);
  } catch (_) {/* sounds are a treat, never a crash */}
}
