// "Smart ears" (beta): a thin bridge to web/smart_listen.js, which runs
// Google's YAMNet sound classifier on the kid's own device and reports
// how speech-like / music-like / instrument-like the last second sounded.
// The audio never leaves the browser. Every call here is fail-safe: if
// the JS side is missing or broken, the app behaves as if smart ears
// were off and practice counting falls back to the plain loudness gate.
import 'dart:convert';
import 'dart:js_interop';

@JS('SmartListen.start')
external void _slStart(JSString instrument);

@JS('SmartListen.stop')
external void _slStop();

@JS('SmartListen.status')
external JSString _slStatus();

/// What smart ears heard in the most recent ~1-second window.
class SmartHearing {
  const SmartHearing({
    required this.ready,
    required this.state,
    required this.speech,
    required this.music,
    required this.instrument,
    required this.clap,
  });

  final bool ready;
  final String state; // off | loading | on | error
  final double speech;
  final double music;
  final double instrument;
  final double clap;

  /// True when the window sounds like talking and not at all like playing.
  /// Deliberately conservative: when in doubt, the kid keeps their minutes.
  bool get speechOnly =>
      ready && speech > 0.3 && music < 0.12 && instrument < 0.1 && clap < 0.1;

  /// A tiny kid-facing word for the banner.
  String get label {
    if (state == 'loading') return 'warming up…';
    if (!ready) return '';
    if (instrument >= 0.1 || music >= 0.2) return 'music!';
    if (clap >= 0.1) return 'clapping';
    if (speech > 0.3) return 'talking';
    return 'quiet';
  }
}

class SmartListen {
  static void start(String instrument) {
    try {
      _slStart(instrument.toJS);
    } catch (_) {}
  }

  static void stop() {
    try {
      _slStop();
    } catch (_) {}
  }

  static SmartHearing? status() {
    try {
      final map = jsonDecode(_slStatus().toDart) as Map<String, dynamic>;
      double n(String k) => (map[k] as num?)?.toDouble() ?? 0;
      return SmartHearing(
        ready: map['ready'] == true,
        state: (map['state'] as String?) ?? 'off',
        speech: n('speech'),
        music: n('music'),
        instrument: n('instrument'),
        clap: n('clap'),
      );
    } catch (_) {
      return null;
    }
  }
}
