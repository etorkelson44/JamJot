import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool get printingSupported => true;
void printPage() => web.window.print();

/// Open synchronously from the Print button to preserve the browser's user gesture.
bool printLessonSheet(String html) {
  final blob =
      web.Blob([html.toJS].toJS, web.BlobPropertyBag(type: 'text/html'));
  final url = web.URL.createObjectURL(blob);
  final opened = web.window.open(url, '_blank');
  // The new document owns its printable snapshot. Revoke the source URL later.
  Future<void>.delayed(
      const Duration(minutes: 5), () => web.URL.revokeObjectURL(url));
  return opened != null;
}
