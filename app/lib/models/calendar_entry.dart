/// Calendar dates use local civil days, not 24-hour durations (DST safe).
DateTime calendarDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);
DateTime calendarDayOffset(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);
DateTime calendarSunday(DateTime date) =>
    calendarDayOffset(date, -(date.weekday % 7));

String calendarDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class CalendarEntry {
  const CalendarEntry(
      {required this.id,
      required this.start,
      required this.record,
      this.end,
      this.isLesson = false});
  final String id;
  final DateTime start;
  final DateTime? end;
  final Map<String, dynamic> record;
  final bool isLesson;
  String get title =>
      (record['title'] as String?) ?? (isLesson ? 'Practice lesson' : 'Event');
  bool get cancelled => record['status'] == 'cancelled';

  bool occursOn(DateTime date) {
    final day = calendarDay(date);
    if (day.isBefore(calendarDay(start))) return false;
    // An end at midnight belongs to the preceding day, like other calendars.
    if (isLesson || end == null || !end!.isAfter(start)) {
      return day == calendarDay(start);
    }
    return day.isBefore(end!) && calendarDayOffset(day, 1).isAfter(start);
  }
}

List<CalendarEntry> calendarEntries({
  required List<Map<String, dynamic>> events,
  required List<Map<String, dynamic>> lessons,
  String? studentId,
}) {
  final entries = <CalendarEntry>[];
  for (final lesson in lessons) {
    if (lesson['event_id'] != null ||
        (studentId != null && lesson['student_id'] != studentId)) {
      continue;
    }
    final date = DateTime.tryParse(lesson['week_start'] as String? ?? '');
    if (date == null) continue;
    entries.add(CalendarEntry(
        id: 'lesson:${lesson['id']}',
        start: calendarDay(date),
        record: lesson,
        isLesson: true));
  }
  for (final event in events) {
    if (studentId != null &&
        !((event['event_students'] as List?) ?? [])
            .any((link) => link['student_id'] == studentId)) {
      continue;
    }
    final start = DateTime.tryParse(event['starts_at'] as String? ?? '');
    if (start == null) continue;
    entries.add(CalendarEntry(
        id: 'event:${event['id']}',
        start: start.toLocal(),
        end: DateTime.tryParse(event['ends_at'] as String? ?? '')?.toLocal(),
        record: event));
  }
  entries.sort((a, b) {
    final day = calendarDay(a.start).compareTo(calendarDay(b.start));
    if (day != 0) return day;
    if (a.isLesson != b.isLesson) return a.isLesson ? -1 : 1;
    final time = a.start.compareTo(b.start);
    return time == 0 ? a.id.compareTo(b.id) : time;
  });
  return entries;
}

/// Fetch every RLS-visible page rather than silently truncating a busy month.
Future<List<Map<String, dynamic>>> readCalendarPages(
    Future<List<Map<String, dynamic>>> Function(int from, int to) fetch,
    {int pageSize = 500}) async {
  final rows = <Map<String, dynamic>>[];
  for (var offset = 0;; offset += pageSize) {
    final page = await fetch(offset, offset + pageSize - 1);
    rows.addAll(page);
    if (page.length < pageSize) return rows;
  }
}
