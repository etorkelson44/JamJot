/// Remembers whether this person wants to stay signed in on this browser,
/// and whether the current browser tab is the one they signed in from.
export 'session_flags_stub.dart'
    if (dart.library.js_interop) 'session_flags_web.dart';

/// How long a kid's tab may sit untouched before the app returns to the
/// profile picker (long enough for a full lesson, short enough that a
/// forgotten shared iPad doesn't stay unlocked all day).
const kidSessionIdle = Duration(minutes: 60);


/// Where the person was when the page reloaded: the router stashes the
/// original location at boot so the gate can put them straight back on it.
String? bootTarget;

/// Session marker meaning "a grown-up is driving" (kids store their id).
const grownUpSession = '__grownup__';
