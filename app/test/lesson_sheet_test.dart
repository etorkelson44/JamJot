import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamjot/screens/lesson/lesson_sheet_screen.dart';
import 'package:jamjot/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const sid = 'sample-student';
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://jamjot-test.invalid',
        publishableKey: 'test-key',
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false, persistSession: false),
        httpClient: MockClient((request) async {
          final rows = request.url.path.endsWith('/sessions')
              ? [
                  {
                    'started_at': '2026-10-27T12:00:00Z',
                    'ended_at': '2026-10-27T12:15:00Z',
                    'total_seconds': 900,
                    'source': 'manual',
                    'entry_note': 'Piano at home',
                    'session_segments': [],
                  }
                ]
              : [];
          return http.Response(jsonEncode(rows), 200,
              request: request, headers: {'content-type': 'application/json'});
        }));
  });
  testWidgets(
      'manual practice prints even when the student has no assigned lesson',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          kidEnrollmentsProvider(sid).overrideWith((ref) async => []),
          sheetExpiryProvider(sid).overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
            home: LessonSheetScreen(
                studentId: sid, studentName: 'Sample musician'))));
    await tester.pumpAndSettle();
    expect(find.text('Practice record'), findsOneWidget);
    expect(find.textContaining('Oct 27'), findsOneWidget);
    expect(find.textContaining('15 min · Manually logged'), findsOneWidget);
    expect(find.textContaining('No assigned lesson yet'), findsOneWidget);
  });
}
