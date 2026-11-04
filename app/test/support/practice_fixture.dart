import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:record/record.dart';
import 'package:jamjot/screens/practice/practice_session_screen.dart';
import 'package:jamjot/state/app_state.dart';
import 'package:jamjot/widgets/fan_stage.dart';

const fixtureStudent = '00000000-0000-4000-8000-000000000001';
const fixtureSession = '00000000-0000-4000-8000-000000000002';
const fixtureSong = '00000000-0000-4000-8000-000000000003';

class FakeRecorder extends AudioRecorder {
  String? path;
  int starts = 0;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    starts++;
    this.path = '${Directory.systemTemp.path}/jamjot-test-take.wav';
    await File(this.path!)
        .writeAsBytes([82, 73, 70, 70, 0, 0, 0, 0, 87, 65, 86, 69]);
  }

  @override
  Future<Amplitude> getAmplitude() async => Amplitude(current: -20, max: -20);
  @override
  Future<bool> isPaused() async => false;
  @override
  Future<String?> stop() async => path;
  @override
  Future<void> dispose() async {}
}

class PracticeFixture {
  int initialSeconds = 0;
  bool failUpload = false;
  bool failSave = false;
  final uploads = <String>[];
  final inserts = <Map<String, dynamic>>[];
  late final http.Client client = MockClient((request) async {
    http.Response reply(String body, int status,
            {Map<String, String>? headers}) =>
        http.Response(body, status, headers: headers ?? {}, request: request);
    final path = request.url.path;
    final single = (request.headers['accept'] ?? '').contains('object');
    if (path.contains('/storage/')) {
      if (request.method == 'POST') {
        uploads.add(path);
        return reply(failUpload ? '{"message":"Offline"}' : '{"Key":"saved"}',
            failUpload ? 503 : 200);
      }
    }
    if (request.method == 'GET' && path.endsWith('/sessions')) {
      // Match the currently published database: this field is not installed.
      if (request.url.queryParameters.containsKey('manual_override_seconds')) {
        return reply(
            '{"message":"column sessions.manual_override_seconds does not exist","code":"42703"}',
            400,
            headers: {'content-type': 'application/json'});
      }
      final rows = initialSeconds == 0
          ? []
          : [
              {
                'id': fixtureSession,
                'total_seconds': initialSeconds,
                'ended_at': null,
                'session_segments': [
                  {
                    'assignment_id': fixtureSong,
                    'seconds': initialSeconds,
                    'wall_seconds': initialSeconds,
                    'completed': false
                  }
                ],
              }
            ];
      return reply(jsonEncode(rows), 200,
          headers: {'content-type': 'application/json'});
    }
    if (request.method == 'POST' && path.endsWith('/sessions')) {
      return reply(jsonEncode({'id': fixtureSession}), 201,
          headers: {'content-type': 'application/json'});
    }
    if (path.endsWith('/session_segments') && request.method == 'POST') {
      final row = Map<String, dynamic>.from(jsonDecode(request.body));
      inserts.add(row);
      if (failSave) return reply('{"message":"Offline","code":"offline"}', 503);
      return reply(jsonEncode(single ? row : [row]), 201,
          headers: {'content-type': 'application/json'});
    }
    if (path.contains('/rpc/')) {
      return reply(
          '{"ok":true,"berries":5,"fans":5,"minutes":1,"goal_met":false}', 200,
          headers: {'content-type': 'application/json'});
    }
    return reply(request.method == 'GET' ? '[]' : '', 200,
        headers: {'content-type': 'application/json'});
  });
  List<Override> overrides(FakeRecorder recorder) => [
        activeStudentProvider.overrideWith(
            (ref) => {'id': fixtureStudent, 'display_name': 'Sample child'}),
        practiceRecorderProvider.overrideWithValue(recorder),
        practiceCutoffProvider(fixtureStudent)
            .overrideWith((ref) async => null),
        currentLessonProvider(fixtureStudent).overrideWith((ref) async => {
              'student_id': fixtureStudent,
              'goal_minutes': 15,
              'goal_days': 4,
              'assignments': [
                {
                  'id': fixtureSong,
                  'title': 'Piano song',
                  'suggested_minutes': 3
                }
              ],
            }),
        weeklyProgressProvider(fixtureStudent)
            .overrideWith((ref) async => {'days': 0, 'today_minutes': 0}),
        berryBalanceProvider(fixtureStudent).overrideWith((ref) async => 0),
        fanTotalProvider(fixtureStudent).overrideWith((ref) async => 0),
        weeklyFansProvider(fixtureStudent).overrideWith((ref) async => 0),
      ];
}
