/// Measures how loud the room is right now (0 = silence, ~1 = loud),
/// so practice timers can count sound instead of silence.
/// The web version listens through the browser; other platforms get a
/// pass-through until their native meters land.
export 'sound_meter_stub.dart'
    if (dart.library.js_interop) 'sound_meter_web.dart';
