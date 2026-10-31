/// Lets the person pick a whole folder; each file keeps its relative path
/// so the library can mirror the computer's organization. Files are read
/// lazily, one at a time — iCloud downloads each on demand as it's read.
export 'folder_picker_stub.dart'
    if (dart.library.js_interop) 'folder_picker_web.dart';

/// One file inside the picked folder, not yet read.
class FolderFileHandle {
  FolderFileHandle({
    required this.name,
    required this.relativePath,
    required this.size,
    required this.read,
  });

  final String name;

  /// e.g. "Suzuki Book 1/Unit 2/Twinkle.pdf"
  final String relativePath;
  final int size;

  /// Reads the bytes (triggering an iCloud download when needed).
  /// Returns null when the file can't be read in a reasonable time.
  final Future<List<int>?> Function() read;
}
