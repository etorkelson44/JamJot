import 'package:web/web.dart' as web;

void setKeepSignedIn(bool keep) {
  try {
    web.window.localStorage.setItem('jj_keep_signed_in', keep ? '1' : '0');
  } catch (_) {}
}

bool get keepSignedIn {
  try {
    return web.window.localStorage.getItem('jj_keep_signed_in') != '0';
  } catch (_) {
    return true;
  }
}

void markThisTabSignedIn() {
  try {
    web.window.sessionStorage.setItem('jj_tab_signed_in', '1');
  } catch (_) {}
}

bool get thisTabSignedIn {
  try {
    return web.window.sessionStorage.getItem('jj_tab_signed_in') == '1';
  } catch (_) {
    return false;
  }
}

// ------------------------------------------------------ active kid session
// The active profile survives a page refresh (sessionStorage lives per tab)
// but not closing the tab; a timestamp lets callers expire idle sessions.

void storeActiveStudent(String? id) {
  try {
    if (id == null) {
      web.window.sessionStorage.removeItem('jj_active_student');
      web.window.sessionStorage.removeItem('jj_last_seen');
    } else {
      web.window.sessionStorage.setItem('jj_active_student', id);
      touchActiveSession();
    }
  } catch (_) {}
}

void touchActiveSession() {
  try {
    web.window.sessionStorage
        .setItem('jj_last_seen', '${DateTime.now().millisecondsSinceEpoch}');
  } catch (_) {}
}

/// The stored student id, or null when absent or idle longer than [maxIdle].
String? freshActiveStudent(Duration maxIdle) {
  try {
    final id = web.window.sessionStorage.getItem('jj_active_student');
    if (id == null || id.isEmpty) return null;
    final seen =
        int.tryParse(web.window.sessionStorage.getItem('jj_last_seen') ?? '');
    if (seen == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - seen;
    if (age > maxIdle.inMilliseconds) {
      storeActiveStudent(null);
      return null;
    }
    return id;
  } catch (_) {
    return null;
  }
}
