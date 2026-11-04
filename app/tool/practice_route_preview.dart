// Local visual verification only: no real account, microphone, or writes.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jamjot/screens/home/home_screen.dart';
import 'package:jamjot/screens/practice/practice_screen.dart';
import 'package:jamjot/screens/practice/practice_session_screen.dart';
import 'package:jamjot/screens/shell.dart';
import 'package:jamjot/state/app_state.dart';
import 'package:jamjot/theme/jamjot_theme.dart';
import 'package:jamjot/widgets/fan_stage.dart';

class PreviewRecorder extends AudioRecorder {
  @override
  Future<bool> hasPermission() async => false;
  @override
  Future<void> dispose() async {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
      url: 'https://jamjot-practice-preview.invalid',
      publishableKey: 'fictional-only',
      authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false, persistSession: false),
      httpClient: MockClient((request) async {
        final unsupportedFilter =
            request.url.queryParameters.containsKey('manual_override_seconds');
        return http.Response(
            jsonEncode(request.method != 'GET'
                ? {'message': 'Read-only local preview'}
                : unsupportedFilter
                    ? {
                        'code': '42703',
                        'message':
                            'column sessions.manual_override_seconds does not exist'
                      }
                    : []),
            request.method != 'GET'
                ? 403
                : unsupportedFilter
                    ? 400
                    : 200,
            request: request,
            headers: {'content-type': 'application/json'});
      }));
  const student = 'fictional-child';
  final router = GoRouter(initialLocation: '/home', routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, __, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen())
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/practice', builder: (_, __) => const PracticeScreen())
        ]),
        for (final route in ['/library', '/market', '/calendar'])
          StatefulShellBranch(routes: [
            GoRoute(
                path: route,
                builder: (_, __) => const Center(
                    child: Text('This preview checks Home and Practice.')))
          ]),
      ],
    ),
    GoRoute(
        path: '/profiles',
        builder: (_, __) => const Center(
            child: Text('Fictional child profile · no account connected.'))),
  ]);
  runApp(ProviderScope(
      overrides: [
        activeStudentProvider.overrideWith((ref) => {
              'id': student,
              'display_name': 'Melody',
              'instruments': ['Piano']
            }),
        practiceRecorderProvider.overrideWithValue(PreviewRecorder()),
        practiceCutoffProvider(student).overrideWith((ref) async => null),
        currentLessonProvider(student).overrideWith((ref) async => {
              'student_id': student,
              'goal_minutes': 15,
              'goal_days': 4,
              'assignments': [
                {
                  'id': 'fictional-song',
                  'title': 'A little piano jam',
                  'suggested_minutes': 3
                }
              ]
            }),
        weeklyProgressProvider(student)
            .overrideWith((ref) async => {'days': 0, 'today_minutes': 0}),
        berryBalanceProvider(student).overrideWith((ref) async => 0),
        fanTotalProvider(student).overrideWith((ref) async => 0),
        weeklyFansProvider(student).overrideWith((ref) async => 0),
        lessonScheduleProvider(student)
            .overrideWith((ref) async => {'last': null, 'next': null}),
        myProfileProvider.overrideWith((ref) async => null),
        myChatsProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp.router(
        title: 'JamJot • Practice preview',
        debugShowCheckedModeBanner: false,
        theme: buildJamJotTheme(JamJotSkin.kid),
        routerConfig: router,
        builder: (context, child) => Column(children: [
          Material(
              color: JamStand.label,
              child: SafeArea(
                  bottom: false,
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                          'Local preview · Fictional child · Older database layout',
                          style: Theme.of(context).textTheme.labelSmall,
                          textAlign: TextAlign.center)))),
          Expanded(child: child!),
        ]),
      )));
}
