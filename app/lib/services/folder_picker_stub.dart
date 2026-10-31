import 'folder_picker.dart';

/// Folder picking is a web feature for now; mobile uses multi-file picking.
bool get folderPickingSupported => false;

Future<List<PickedFolderFile>> pickFolderFiles() async => [];
