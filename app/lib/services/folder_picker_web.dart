import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'folder_picker.dart';

bool get folderPickingSupported => true;

/// File types the library understands; everything else is left untouched.
const _allowed = {'pdf', 'png', 'jpg', 'jpeg', 'xml', 'musicxml', 'mxl'};

/// Skip anything over 25 MB — bigger than any sheet-music scan.
const _maxBytes = 25 * 1024 * 1024;

/// Patience per file: plenty for iCloud to download it on demand.
const _readTimeout = Duration(seconds: 90);

/// Opens the browser's folder picker and hands back lazy handles for the
/// usable music files inside — nothing is read until each is uploaded.
Future<List<FolderFileHandle>> pickFolderFiles() async {
  final input =
      web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.setAttribute('webkitdirectory', '');
  final completer = Completer<List<FolderFileHandle>>();

  input.addEventListener(
    'change',
    ((web.Event _) {
      final files = input.files;
      final out = <FolderFileHandle>[];
      if (files != null) {
        for (var i = 0; i < files.length; i++) {
          final f = files.item(i)!;
          if (f.name.startsWith('.')) continue;
          final dot = f.name.lastIndexOf('.');
          final ext =
              dot < 0 ? '' : f.name.substring(dot + 1).toLowerCase();
          if (!_allowed.contains(ext)) continue;
          if (f.size > _maxBytes) continue;
          final rel = f.webkitRelativePath;
          out.add(FolderFileHandle(
            name: f.name,
            relativePath: rel.isEmpty ? f.name : rel,
            size: f.size,
            read: () async {
              try {
                final buf =
                    await f.arrayBuffer().toDart.timeout(_readTimeout);
                return buf.toDart.asUint8List();
              } catch (_) {
                return null;
              }
            },
          ));
        }
      }
      if (!completer.isCompleted) completer.complete(out);
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
