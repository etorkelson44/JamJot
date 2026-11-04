// Fictional local review only. Network writes are rejected by the mock client.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jamjot/screens/calendar/calendar_screen.dart';
import 'package:jamjot/state/app_state.dart';
import 'package:jamjot/theme/jamjot_theme.dart';
import 'package:jamjot/models/calendar_entry.dart';

final previewRole = StateProvider<String>((ref) => 'Caregiver');
final previewEmpty = StateProvider<bool>((ref) => false);
final previewFailure = StateProvider<bool>((ref) => false);

List<Map<String, dynamic>> sampleEvents() {
  final today = calendarDay(DateTime.now());
  final sunday = calendarSunday(today);
  Map<String, dynamic> entry(String id, String title, DateTime date,
          {String student = 'melody',
          String kind = 'lesson',
          bool cancelled = false}) =>
      {
        'id': id,
        'title': title,
        'owner_id': 'fictional-teacher',
        'kind': kind,
        'starts_at': date.toUtc().toIso8601String(),
        'ends_at':
            date.add(const Duration(minutes: 45)).toUtc().toIso8601String(),
        'status': cancelled ? 'cancelled' : 'scheduled',
        'notes': 'Fictional event for local calendar review.',
        'teachers': {'display_name': 'Jordan'},
        'event_students': [
          {
            'student_id': student,
            'students': {
              'display_name': student == 'melody' ? 'Melody' : 'Aria'
            }
          }
        ],
      };
  return [
    entry('late', 'Piano lesson',
        DateTime(today.year, today.month, today.day, 15, 30)),
    entry('sun', 'Sunday ensemble',
        DateTime(sunday.year, sunday.month, sunday.day, 11)),
    entry('morning', 'Morning warm-up',
        DateTime(today.year, today.month, today.day, 8)),
    entry('sat', 'Studio recital',
        DateTime(sunday.year, sunday.month, sunday.day + 6, 14),
        kind: 'performance'),
    entry('family', 'A little family jam',
        DateTime(today.year, today.month, today.day + 2, 17),
        kind: 'family'),
    entry('other', 'Aria’s violin lesson',
        DateTime(today.year, today.month, today.day, 16),
        student: 'aria'),
    entry(
        'long',
        'Ensemble rehearsal — a very long title that stays inside its day',
        DateTime(today.year, today.month, today.day + 4, 10)),
    entry('cancelled', 'Theory workshop',
        DateTime(today.year, today.month, today.day + 5, 12),
        cancelled: true),
    entry('older', 'Last month’s concert',
        DateTime(today.year, today.month - 1, 12, 10),
        kind: 'performance'),
  ];
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
      url: 'https://jamjot-calendar-preview.invalid',
      publishableKey: 'fictional-only',
      authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false, persistSession: false),
      httpClient: MockClient((request) async => http.Response(
          request.method == 'GET' ? '[]' : '{"message":"Local preview only"}',
          request.method == 'GET' ? 200 : 403,
          headers: {'content-type': 'application/json'})));
  runApp(ProviderScope(overrides: [
    calendarEventsProvider.overrideWith((ref) async {
      if (ref.watch(previewFailure)) throw Exception('Fictional offline state');
      final role = ref.watch(previewRole);
      if (ref.watch(previewEmpty)) return [];
      return sampleEvents()
          .where((event) =>
              (role != 'Teacher' && role != 'Studio') ||
              event['kind'] != 'family')
          .toList();
    }),
    assignedLessonsProvider.overrideWith((ref) async => []),
    myStudentsProvider.overrideWith((ref) async => []),
    myTeacherProvider.overrideWith((ref) async => null),
  ], child: const CalendarPreview()));
}

class CalendarPreview extends ConsumerWidget {
  const CalendarPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(previewRole);
    return MaterialApp(
        title: 'JamJot • Calendar preview',
        theme: buildJamJotTheme(
            role == 'Student' ? JamJotSkin.kid : JamJotSkin.grownup),
        home: Scaffold(
            body: SafeArea(
                child: Column(children: [
          Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Local calendar preview · Fictional data'),
                        for (final name in [
                          'Caregiver',
                          'Teacher',
                          'Studio',
                          'Student'
                        ])
                          ChoiceChip(
                              label: Text(name),
                              selected: role == name,
                              onSelected: (_) {
                                ref.read(previewRole.notifier).state = name;
                                ref.read(activeStudentProvider.notifier).state =
                                    name == 'Student'
                                        ? {
                                            'id': 'melody',
                                            'display_name': 'Melody'
                                          }
                                        : null;
                              }),
                        FilterChip(
                            label: const Text('Empty calendar'),
                            selected: ref.watch(previewEmpty),
                            onSelected: (value) =>
                                ref.read(previewEmpty.notifier).state = value),
                        FilterChip(
                            label: const Text('Load error'),
                            selected: ref.watch(previewFailure),
                            onSelected: (value) => ref
                                .read(previewFailure.notifier)
                                .state = value),
                      ]))),
          const Expanded(child: CalendarScreen(readOnly: true)),
        ]))));
  }
}
