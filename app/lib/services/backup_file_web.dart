import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<bool> saveBackupFile(Uint8List bytes, String name) async {
  final blob =
      web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/zip'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // Allow the browser to acquire the Blob before releasing its URL.
  Future<void>.delayed(
      const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  return true; // A request was handed to the browser, not proof of a saved file.
}
