/// While on, the browser warns before closing or leaving the page
/// (used during uploads so progress isn't lost by accident).
export 'unload_guard_stub.dart'
    if (dart.library.js_interop) 'unload_guard_web.dart';
