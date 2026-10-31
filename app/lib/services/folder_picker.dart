/// Lets the person pick a whole folder; each file keeps its relative path
/// so the library can mirror the computer's organization.
export 'folder_picker_stub.dart'
    if (dart.library.js_interop) 'folder_picker_web.dart';

class PickedFolderFile {
  PickedFolderFile(
      {required this.name, required this.relativePath, required this.bytes});

  final String name;

  /// e.g. "Suzuki Book 1/Unit 2/Twinkle.pdf"
  final String relativePath;
  final List<int> bytes;
}
