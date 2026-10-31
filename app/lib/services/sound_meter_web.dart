import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web sound meter: taps the microphone through the browser's audio engine
/// and reports the room's loudness as a 0..1 number.
class SoundMeter {
  web.AudioContext? _ctx;
  web.AnalyserNode? _analyser;
  web.MediaStream? _stream;

  Future<bool> start() async {
    try {
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;
      _stream = stream;
      final ctx = web.AudioContext();
      _ctx = ctx;
      final src = ctx.createMediaStreamSource(stream);
      final analyser = ctx.createAnalyser();
      analyser.fftSize = 1024;
      src.connect(analyser);
      _analyser = analyser;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Root-mean-square loudness of the current audio frame, 0..1.
  double get level {
    final analyser = _analyser;
    if (analyser == null) return 0;
    final data = Uint8List(analyser.fftSize);
    analyser.getByteTimeDomainData(data.toJS);
    var sum = 0.0;
    for (final v in data) {
      final centered = (v - 128) / 128.0;
      sum += centered * centered;
    }
    return math.sqrt(sum / data.length);
  }

  void stop() {
    final tracks = _stream?.getTracks().toDart;
    if (tracks != null) {
      for (final t in tracks) {
        t.stop();
      }
    }
    _ctx?.close();
    _analyser = null;
    _ctx = null;
    _stream = null;
  }
}
