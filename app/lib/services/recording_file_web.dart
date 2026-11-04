import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

Future<String> recordingPath(String id) async => '';
Future<Uint8List> readRecording(String path) async {
  final response = await http.get(Uri.parse(path));
  if (response.statusCode != 200) {
    throw StateError('Recording could not be read.');
  }
  return response.bodyBytes;
}

Future<void> releaseRecording(String path) async {
  if (path.startsWith('blob:')) web.URL.revokeObjectURL(path);
}
