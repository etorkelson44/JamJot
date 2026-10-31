import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'folder_picker.dart';

bool get folderPickingSupported => true;

/// File types the library understands; everything else is left untouched.
const _allowed = {'pdf', 'png', 'jpg', 'jpeg', 'xml', 'musicxml', 'mxl'};

/// Skip anything over 25 MB — bigger than any sheet-music scan.
const _maxBytes = 25 * 1024 * 1024;

/// Opens the browser's folder picker and reads only the usable music
/// files inside, keeping each one's path within the chosen folder.
Future<List<PickedFolderFile>> pickFolderFiles() async {
  final input =
      web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.setAttribute('webkitdirectory', '');
  final completer = Completer<List<PickedFolderFile>>();

  input.addEventListener(
    'change',
    ((web.Event _) {
      _readAll(input, completer);
    }).toJS,
  );
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!completer.isCompleted) completer.complete([]);
    }).toJS,
  );
  input.click();
  return completer.future;
}

Future<void> _readAll(web.HTMLInputElement input,
    Completer<List<PickedFolderFile>> completer) async {
  final files = input.files;
  final out = <PickedFolderFile>[];
  if (files != null) {
    for (var i = 0; i < files.length; i++) {
      final f = files.item(i)!;
      // Skip hidden files like .DS_Store.
      if (f.name.startsWith('.')) continue;
      // Only music-type files, and nothing enormous.
      final dot = f.name.lastIndexOf('.');
      final ext = dot < 0 ? '' : f.name.substring(dot + 1).toLowerCase();
      if (!_allowed.contains(ext)) continue;
      if (f.size > _maxBytes) continue;
      try {
        final buf = await f.arrayBuffer().toDart;
        final bytes = buf.toDart.asUint8List();
        final rel = f.webkitRelativePath;
        out.add(PickedFolderFile(
          name: f.name,
          relativePath: rel.isEmpty ? f.name : rel,
          bytes: bytes,
        ));
      } catch (_) {/* unreadable file: skip it */}
    }
  }
  if (!completer.isCompleted) completer.complete(out);
}
