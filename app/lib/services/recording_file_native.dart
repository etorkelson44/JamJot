import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> recordingPath(String id) async =>
    '${(await getTemporaryDirectory()).path}/jamjot-$id.wav';
Future<Uint8List> readRecording(String path) => File(path).readAsBytes();
Future<void> releaseRecording(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}
