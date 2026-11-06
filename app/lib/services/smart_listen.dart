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
    this.impulses = 0,
  });

  final bool ready;
  final String state; // off | loading | on | error
  final double speech;
  final double music;
  final double instrument;
  final double clap;

  /// Sharp clap-like hits counted in the raw audio of the last ~1.5 s,
  /// independent of the sound model (which often under-rates a clap when a
  /// voice is loud over it).
  final int impulses;

  /// Hand-claps are audible in the raw sound: two or more sharp hits, or
  /// one hit with at least a faint clap score from the model.
  bool get clappy =>
      ready && (clap >= 0.08 || impulses >= 2 || (impulses >= 1 && clap >= 0.03));

  /// Clapping together with a voice — a kid clapping while counting out
  /// loud or naming the notes — is real practice (founder-directed
  /// 2026-11-05, extended 2026-11-06 for naming notes while clapping), so
  /// it overrides the talking exclusion.
  bool get clapAndVoice => ready && speech >= 0.2 && clappy;

  /// True when the window sounds like talking and not at all like playing.
  /// Deliberately conservative: when in doubt, the kid keeps their minutes.
  bool get speechOnly =>
      ready &&
      !clapAndVoice &&
      speech > 0.3 &&
      music < 0.12 &&
      instrument < 0.1 &&
      clap < 0.1 &&
      impulses < 2;

  /// A tiny kid-facing word for the banner.
  String get label {
    if (state == 'loading') return 'warming up…';
    if (!ready) return '';
    if (instrument >= 0.1 || music >= 0.2) return 'music!';
    if (clapAndVoice) return 'clap & count!';
    if (clap >= 0.1 || impulses >= 2) return 'clapping';
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
        impulses: n('impulses').round(),
      );
    } catch (_) {
      return null;
    }
  }
}
