import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jamjot/screens/calendar/calendar_screen.dart';
import 'package:jamjot/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://calendar-test.invalid',
        publishableKey: 'fictional',
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false, persistSession: false),
        httpClient: MockClient((_) async => http.Response('[]', 200,
            headers: {'content-type': 'application/json'})));
  });
  final rows = <Map<String, dynamic>>[
    {
      'id': 'fictional',
      'title': 'A long rehearsal title with space to read every word',
      'starts_at': DateTime.now().toUtc().toIso8601String(),
      'ends_at': DateTime.now()
          .add(const Duration(hours: 1))
          .toUtc()
          .toIso8601String(),
      'kind': 'performance',
      'owner_id': 'someone',
      'event_students': [
        {
          'student_id': 'melody',
          'students': {'display_name': 'Melody'}
        }
      ],
    }
  ];
  Widget app(Future<List<Map<String, dynamic>>> Function() load,
          {double scale = 1}) =>
      ProviderScope(
          overrides: [
            calendarEventsProvider.overrideWith((ref) => load()),
            assignedLessonsProvider.overrideWith((ref) async => []),
            myTeacherProvider.overrideWith((ref) async => null),
            myStudentsProvider.overrideWith((ref) async => []),
            activeStudentProvider.overrideWith((ref) => null)
          ],
          child: MaterialApp(
              home: Scaffold(
                  body: MediaQuery(
                      data: MediaQueryData(
                          size: const Size(375, 812),
                          textScaler: TextScaler.linear(scale)),
                      child: const CalendarScreen()))));
  testWidgets(
      'loading and failed requests never masquerade as an empty calendar; retry recovers',
      (tester) async {
    final request = Completer<List<Map<String, dynamic>>>();
    var count = 0;
    await tester.pumpWidget(
        app(() => ++count == 1 ? request.future : Future.value(rows)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    request.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Your calendar could not be loaded. Please try again.'),
        findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text(rows.single['title']), findsOneWidget);
  });
  testWidgets(
      'real event cards and adult controls fit phone at double text size',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(() async => rows, scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final mode in ['day', 'week', 'month', 'agenda']) {
      final target = find.byKey(ValueKey('calendar-view-$mode'));
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
