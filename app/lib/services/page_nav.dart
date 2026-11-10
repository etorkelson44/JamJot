/// Whole-page browser actions for the "jammed up" page. They reload or
/// leave the page outright, so they still work when the app's own router
/// or screens are what broke. (No-ops off the web.)
export 'page_nav_stub.dart' if (dart.library.js_interop) 'page_nav_web.dart';
