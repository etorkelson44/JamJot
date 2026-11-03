import 'dart:js_interop';

import 'package:web/web.dart' as web;

JSFunction? _handler;

/// While on, closing the tab/window or navigating away makes the browser
/// ask "are you sure?" (browsers show their own standard wording).
void setUnloadGuard(bool on) {
  if (on && _handler == null) {
    _handler = ((web.BeforeUnloadEvent e) {
      e.preventDefault();
      e.returnValue = 'Files are still uploading.';
    }).toJS;
    web.window.addEventListener('beforeunload', _handler);
  } else if (!on && _handler != null) {
    web.window.removeEventListener('beforeunload', _handler);
    _handler = null;
  }
}
