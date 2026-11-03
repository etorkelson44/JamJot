// Local visual QA only. All backend calls and microphone access are replaced.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jamjot/screens/practice/practice_session_screen.dart';
import 'package:jamjot/screens/lesson/lesson_sheet_screen.dart';
import 'package:jamjot/screens/history/practice_history_screen.dart';
import 'package:jamjot/state/app_state.dart';
import 'package:jamjot/widgets/fan_stage.dart';
import 'package:jamjot/widgets/letter_avatar.dart';
import 'package:jamjot/theme/jamjot_theme.dart';

const sid = '00000000-0000-4000-8000-000000000001';
const sessionId = '00000000-0000-4000-8000-000000000002';
const songId = '00000000-0000-4000-8000-000000000003';

class PreviewRecorder extends AudioRecorder {
  @override
  Future<bool> hasPermission() async => false;
  @override
  Future<void> dispose() async {}
}

final lesson = <String, dynamic>{
  'student_id': sid,
  'title': 'This week at the piano',
  'source': 'Family',
  'week_start': '2026-10-26',
  'goal_minutes': 15,
  'goal_days': 4,
  'lesson_note': 'Keep a steady beat and enjoy making music.',
  'assignments': [
    {
      'id': songId,
      'title': 'Morning song',
      'suggested_minutes': 3,
      'song_note': 'Try the left hand slowly, then put both hands together.',
      'order_idx': 0
    }
  ],
  'practice_rows': [
    {
      'id': sessionId,
      'student_id': sid,
      'started_at': '2026-10-27T12:00:00Z',
      'ended_at': '2026-10-27T12:15:00Z',
      'total_seconds': 900,
      'source': 'manual',
      'entry_note': 'Piano practice at home',
      'goal_met': true,
      'session_segments': []
    }
  ],
};
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
      url: 'https://jamjot-preview.invalid',
      publishableKey: 'preview-only',
      authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false, persistSession: false),
      httpClient: MockClient((request) async {
        Object data = [];
        if (request.method == 'GET' && request.url.path.endsWith('/sessions')) {
          data = [
            {
              'id': sessionId,
              'total_seconds': 60,
              'ended_at': null,
              'session_segments': [
                {
                  'assignment_id': songId,
                  'seconds': 60,
                  'wall_seconds': 75,
                  'completed': false
                }
              ]
            }
          ];
        }
        if (request.url.path.contains('/rpc/')) {
          data = {
            'ok': true,
            'berries': 5,
            'fans': 5,
            'minutes': 1,
            'goal_met': false
          };
        }
        if (request.url.path.endsWith('/session_segments') &&
            request.method == 'POST') {
          data = jsonDecode(request.body);
        }
        return http.Response(jsonEncode(data), 200,
            request: request, headers: {'content-type': 'application/json'});
      }));
  runApp(ProviderScope(overrides: [
    activeStudentProvider.overrideWith((ref) => {
          'id': sid,
          'display_name': 'Sample musician',
          'avatar_key': 'blueberry'
        }),
    practiceRecorderProvider.overrideWithValue(PreviewRecorder()),
    currentLessonProvider(sid).overrideWith((ref) async => lesson),
    practiceCutoffProvider(sid).overrideWith((ref) async => null),
    sheetLessonsProvider(sid).overrideWith((ref) async => [lesson]),
    sheetExpiryProvider(sid).overrideWith((ref) async => null),
    practiceHistoryProvider(sid).overrideWith((ref) async =>
        {'sessions': lesson['practice_rows'], 'rewards': <String, String>{}}),
    canCorrectPracticeProvider(sid).overrideWith((ref) async => true),
    weeklyProgressProvider(sid)
        .overrideWith((ref) async => {'days': 1, 'today_minutes': 0}),
    berryBalanceProvider(sid).overrideWith((ref) async => 25),
    fanTotalProvider(sid).overrideWith((ref) async => 5),
    weeklyFansProvider(sid).overrideWith((ref) async => 5),
  ], child: const PreviewApp()));
}

class PreviewApp extends StatefulWidget {
  const PreviewApp({super.key});
  @override
  State<PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<PreviewApp> {
  int page = 0;
  double scale = 1;
  @override
  Widget build(BuildContext context) => MaterialApp(
      theme: buildJamJotTheme(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Scaffold(
          body: Column(children: [
        SafeArea(
            bottom: false,
            child: Wrap(spacing: 8, children: [
              for (final (i, label) in [
                (0, 'Practice'),
                (1, 'Sheet'),
                (2, 'History')
              ])
                TextButton(
                    onPressed: () => setState(() => page = i),
                    child: Text(label)),
              TextButton(
                  onPressed: () => setState(() => scale = scale == 1 ? 2 : 1),
                  child: Text('Text ${scale.toInt()}×')),
              const LetterAvatar(
                  name: 'Sample', avatarKey: 'blueberry', size: 44),
            ])),
        const Text('Sample data · microphone disabled'),
        Expanded(
            child: switch (page) {
          0 => const PracticeSessionScreen(),
          1 => const LessonSheetScreen(
              studentId: sid, studentName: 'Sample musician'),
          _ => const PracticeHistoryList(studentId: sid)
        }),
      ])));
}
