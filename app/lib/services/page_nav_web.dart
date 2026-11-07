import 'package:web/web.dart' as web;

/// Reload the current page.
void reloadPage() => web.window.location.reload();

/// Go to the app's start page — the document's base address, which is
/// wherever the app is hosted (e.g. / on jamjot.app, /JamJot/ on GitHub Pages).
void goToStartPage() {
  web.window.location.href = web.document.baseURI;
}
