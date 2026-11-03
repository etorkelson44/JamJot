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
