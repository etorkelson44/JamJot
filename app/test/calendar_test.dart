import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/models/calendar_entry.dart';
import 'package:jamjot/widgets/calendar_views.dart';
import 'package:jamjot/theme/jamjot_theme.dart';

Map<String, dynamic> event(String id, DateTime start,
        {DateTime? end, String student = 'melody', String? title}) =>
    {
      'id': id,
      'title': title ?? id,
      'starts_at': start.toUtc().toIso8601String(),
      'ends_at': end?.toUtc().toIso8601String(),
      'event_students': [
        {'student_id': student}
      ],
    };
final today = DateTime(2026, 11, 4);
final fixture = calendarEntries(events: [
  event('Afternoon lesson', DateTime(2026, 11, 4, 15)),
  event('Sunday concert', DateTime(2026, 11, 1, 10)),
  event('Morning practice', DateTime(2026, 11, 4, 8)),
  event('Saturday recital', DateTime(2026, 11, 7, 14)),
], lessons: []);

void main() {
  test('Sunday-first boundaries, leap month, DST-safe civil day arithmetic',
      () {
    expect(calendarSunday(today), DateTime(2026, 11, 1));
    expect(calendarSunday(DateTime(2026, 11, 1)), DateTime(2026, 11, 1));
    expect(calendarSunday(DateTime(2027, 1, 1)), DateTime(2026, 12, 27));
    expect(calendarDayOffset(DateTime(2028, 2, 28), 1), DateTime(2028, 2, 29));
    expect(calendarDayOffset(DateTime(2026, 3, 8), 1).hour, 0);
    expect(calendarDayOffset(DateTime(2026, 11, 1), 1), DateTime(2026, 11, 2));
  });
  test(
      'chronological local dates, child isolation, assigned lessons without duplicates',
      () {
    final entries = calendarEntries(events: [
      event('later', DateTime(2026, 11, 4, 19)),
      event('other child', today, student: 'other'),
      event('early', DateTime(2026, 11, 4, 1)),
    ], lessons: [
      {'id': 'assigned', 'student_id': 'melody', 'week_start': '2026-11-04'},
      {
        'id': 'linked',
        'student_id': 'melody',
        'week_start': '2026-11-04',
        'event_id': 'later'
      },
      {'id': 'other lesson', 'student_id': 'other', 'week_start': '2026-11-04'},
    ], studentId: 'melody');
    expect(entries.map((e) => e.id),
        ['lesson:assigned', 'event:early', 'event:later']);
    expect(entries[1].start, DateTime(2026, 11, 4, 1));
  });
  test(
      'overnight events occupy each day, exclusive midnight end does not spill',
      () {
    final entries = calendarEntries(events: [
      event('overnight', DateTime(2026, 10, 31, 23), end: DateTime(2026, 11, 2))
    ], lessons: []);
    expect(entries.single.occursOn(DateTime(2026, 10, 31)), true);
    expect(entries.single.occursOn(DateTime(2026, 11, 1)), true);
    expect(entries.single.occursOn(DateTime(2026, 11, 2)), false);
  });
  test('pagination includes records after former event/lesson limits',
      () async {
    final requested = <int>[];
    final rows = await readCalendarPages((from, to) async {
      requested.add(from);
      return [
        for (var i = from; i <= to && i < 1203; i++) {'id': '$i'}
      ];
    });
    expect(requested, [0, 500, 1000]);
    expect(rows.length, 1203);
    expect(rows.last['id'], '1202');
  });

  Future<void> pumpCalendar(WidgetTester tester,
      {List<CalendarEntry>? entries,
      double width = 1200,
      double scale = 1,
      bool kid = false}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Fonts are inherited; use the profile palette without network font fetching.
    final theme = ThemeData(
        colorScheme: ColorScheme.light(
            primary: kid ? JamStand.ink : CalmStudio.blueberry,
            onSurface: kid ? JamStand.ink : CalmStudio.ink),
        scaffoldBackgroundColor: kid ? JamStand.paper : CalmStudio.base);
    await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
            body: MediaQuery(
                data: MediaQueryData(
                    size: Size(width, 900),
                    textScaler: TextScaler.linear(scale)),
                child: SingleChildScrollView(
                    child: CalendarViews(
                        entries: entries ?? fixture,
                        now: () => today,
                        detailBuilder: (_, entry) =>
                            Text('Detail: ${entry.title}')))))));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String mode) async {
    final target = find.byKey(ValueKey('calendar-view-$mode'));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('All is chronological; Day dates today; Week always has Sun–Sat',
      (tester) async {
    await pumpCalendar(tester);
    final ordered = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((text) => text?.startsWith('Detail:') ?? false);
    expect(ordered, [
      'Detail: Sunday concert',
      'Detail: Morning practice',
      'Detail: Afternoon lesson',
      'Detail: Saturday recital'
    ]);
    await choose(tester, 'day');
    expect(find.text('Wednesday, November 4'), findsOneWidget);
    expect(find.text('Detail: Sunday concert'), findsNothing);
    await choose(tester, 'week');
    for (var i = 1; i <= 7; i++) {
      expect(find.byKey(ValueKey('cell-2026-11-0$i')), findsOneWidget);
    }
    expect(find.text('Nothing scheduled'), findsNWidgets(4));
    expect(find.text('Today'), findsNWidgets(2)); // Navigation and dated cell.
  });
  testWidgets('Month places every event in its date box and opens details',
      (tester) async {
    await pumpCalendar(tester);
    await choose(tester, 'month');
    final wednesday = find.byKey(const ValueKey('cell-2026-11-04'));
    expect(
        find.descendant(of: wednesday, matching: find.text('Morning practice')),
        findsOneWidget);
    expect(
        find.descendant(of: wednesday, matching: find.text('Afternoon lesson')),
        findsOneWidget);
    expect(
        find.descendant(of: wednesday, matching: find.text('Sunday concert')),
        findsNothing);
    await tester.tap(find.text('Morning practice'));
    await tester.pumpAndSettle();
    expect(find.text('Detail: Morning practice'), findsOneWidget);
    await tester.tap(find.byTooltip('Close event details'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
  });
  testWidgets('Approved Maestro empty state only when All has no entries',
      (tester) async {
    await pumpCalendar(tester, entries: []);
    expect(
        find.text('I’ve searched every measure… no jams on the calendar yet!'),
        findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await choose(tester, 'week');
    expect(find.byType(Image), findsNothing);
    expect(find.text('Nothing scheduled'), findsNWidgets(7));
  });
  for (final kid in [false, true]) {
    for (final size in [(375.0, 1.0), (375.0, 2.0), (844.0, 1.0)]) {
      testWidgets(
          'All views fit ${kid ? 'kid' : 'adult'} at ${size.$1}px / ${size.$2}x',
          (tester) async {
        final crowded = calendarEntries(events: [
          for (var i = 0; i < 9; i++)
            event('$i', DateTime(2026, 11, 4, 8 + i),
                title:
                    'A long musical rehearsal title with room for every event $i')
        ], lessons: []);
        await pumpCalendar(tester,
            entries: crowded, width: size.$1, scale: size.$2, kid: kid);
        for (final mode in ['day', 'week', 'month', 'agenda']) {
          await choose(tester, mode);
          expect(tester.takeException(), isNull);
        }
        await choose(tester, 'month');
        final box = find.byKey(const ValueKey('cell-2026-11-04'));
        expect(
            find.descendant(
                of: box,
                matching: find.textContaining('A long musical rehearsal')),
            findsNWidgets(9));
      });
    }
  }
}
