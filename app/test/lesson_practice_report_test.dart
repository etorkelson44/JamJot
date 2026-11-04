import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/models/lesson_practice_report.dart';

void main() {
  final lesson = <String, dynamic>{
    'title': 'Piano & singing',
    'source': 'Family',
    'week_start': '2026-10-26',
    'goal_days': 4,
    'goal_minutes': 15,
    'assignments': [
      {'title': 'Song one', 'song_note': '<script>do not execute</script>'}
    ],
  };
  Map<String, dynamic> session(String at,
          {String source = 'app', bool finished = true}) =>
      {
        'started_at': at,
        'ended_at': finished ? at : null,
        'total_seconds': 900,
        'source': source,
        'entry_note': source == 'manual' ? 'Piano at home' : null,
      };
  test(
      'lesson window includes manual and recorded practice, excludes unfinished and next week',
      () {
    final rows = practicesForLesson(
        lesson,
        [
          session('2026-10-25T12:00:00'),
          session('2026-10-27T12:00:00', source: 'manual'),
          session('2026-11-01T23:59:00'),
          session('2026-11-02T00:00:00'),
          session('2026-10-28T12:00:00', finished: false),
        ],
        DateTime(2026, 11, 3));
    expect(rows, hasLength(2));
    expect(rows.first['source'], 'manual');
    expect(rows.fold<int>(0, (sum, r) => sum + creditedSeconds(r)), 1800);
  });
  test(
      'print document contains every practice, manual minutes and an explicit snapshot cutoff',
      () {
    final html = lessonReportHtml(
        studentName: 'Ben <&>',
        lessons: [
          {
            ...lesson,
            'practice_rows': List.generate(
                35, (_) => session('2026-10-27T12:00:00', source: 'manual')),
          }
        ],
        generatedAt: DateTime(2026, 10, 31, 12),
        validUntil: DateTime(2026, 11, 1));
    expect('Manually logged'.allMatches(html), hasLength(35));
    expect(html, contains('525 minutes'));
    expect(html, contains('2026-11-01 00:00:00'));
    expect(html, contains('Ben &lt;&amp;&gt;'));
    expect(html, isNot(contains('<script>')));
    expect(html, contains('break-before:page'));
  });
  test('manual correction is authoritative even when recordings remain', () {
    expect(
        creditedSeconds({
          'total_seconds': 300,
          'recorded_seconds': 900,
          'manual_override_seconds': 300
        }),
        300);
  });
}
