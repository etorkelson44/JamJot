import 'dart:convert';

/// Calendar dates are evaluated in the viewer's local timezone, matching practice.
DateTime lessonWindowStart(Map<String, dynamic> lesson, DateTime now) {
  final date = DateTime.tryParse(lesson['week_start'] as String? ?? '');
  return date ??
      DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
}

List<Map<String, dynamic>> practicesForLesson(Map<String, dynamic> lesson,
    List<Map<String, dynamic>> sessions, DateTime now) {
  final start = lessonWindowStart(lesson, now);
  final end = DateTime(start.year, start.month, start.day + 7);
  return sessions.where((row) {
    final at = DateTime.parse(row['started_at'] as String).toLocal();
    return row['ended_at'] != null && !at.isBefore(start) && at.isBefore(end);
  }).toList();
}

int creditedSeconds(Map<String, dynamic> session) =>
    (session['total_seconds'] as num?)?.toInt() ?? 0;

String htmlText(Object? value) => const HtmlEscape().convert('${value ?? ''}');

/// A semantic HTML document prints every row, independent of Flutter's viewport.
String lessonReportHtml(
    {required String studentName,
    required List<Map<String, dynamic>> lessons,
    required DateTime generatedAt,
    required DateTime validUntil}) {
  String date(DateTime at) => '${at.month}/${at.day}/${at.year}';
  final body = StringBuffer();
  for (final lesson in lessons) {
    final sessions =
        (lesson['practice_rows'] as List? ?? []).cast<Map<String, dynamic>>();
    final total = sessions.fold<int>(0, (sum, r) => sum + creditedSeconds(r));
    body.write('<section><h2>${htmlText(lesson['title'])}</h2>'
        '<p>${htmlText(lesson['source'])} · Week of ${date(lessonWindowStart(lesson, generatedAt))}</p>'
        '<p>Goal: ${htmlText(lesson['goal_days'] ?? 4)} days, '
        '${htmlText(lesson['goal_minutes'] ?? 15)} minutes a day</p>'
        '<p>${htmlText(lesson['lesson_note'])}</p><h3>Assigned music</h3><ol>');
    for (final song in lesson['assignments'] as List? ?? []) {
      body.write('<li><strong>${htmlText(song['title'])}</strong>'
          '<p>${htmlText(song['song_note'])}</p></li>');
    }
    body.write(
        '</ol><h3>Practice this lesson week · ${total ~/ 60} minutes</h3>'
        '<table><thead><tr><th>Date</th><th>Minutes</th><th>Practice</th></tr></thead><tbody>');
    for (final row in sessions) {
      final at = DateTime.parse(row['started_at'] as String).toLocal();
      body.write(
          '<tr><td>${date(at)}</td><td>${creditedSeconds(row) ~/ 60}</td>'
          '<td>${row['source'] == 'manual' ? 'Manually logged' : 'Recorded practice'}'
          '${row['entry_note'] == null ? '' : ' — ${htmlText(row['entry_note'])}'}</td></tr>');
      for (final seg in row['session_segments'] as List? ?? []) {
        body.write(
            '<tr><td></td><td>${((seg['seconds'] as num?)?.toInt() ?? 0) ~/ 60}</td>'
            '<td>${htmlText((seg['assignments'] as Map?)?['title'] ?? 'Free play')}</td></tr>');
      }
    }
    if (sessions.isEmpty) {
      body.write(
          '<tr><td colspan="3">No saved practice in this lesson week yet.</td></tr>');
    }
    body.write(
        '</tbody></table><p class="note">Manual entries without song details count toward the weekly total; they are not assigned to an individual song.</p></section>');
  }
  return '''<!doctype html><html><head><meta charset="utf-8"><title>${htmlText(studentName)} — JamJot lesson sheet</title>
<style>@page{size:auto;margin:16mm}body{font-family:Arial,sans-serif;color:#26323E;line-height:1.45;max-width:850px;margin:24px auto}h1{font-size:26px}h2{font-size:21px;margin-top:28px}h3{font-size:16px}p{margin:6px 0}table{border-collapse:collapse;width:100%;margin-top:12px}th,td{text-align:left;border-bottom:1px solid #bbb;padding:8px;vertical-align:top}thead{display:table-header-group}tr,li{break-inside:avoid}.note{font-size:12px}button{padding:12px 20px;font:inherit}@media print{button{display:none}body{margin:0}section+section{break-before:page}}</style></head><body><button onclick="window.print()">Print / Save as PDF</button>
<h1>${htmlText(studentName)}'s JamJot lesson sheet</h1><p>Updated ${htmlText(generatedAt.toString().split('.').first)}</p>
<p class="note">Practice snapshot valid until ${htmlText(validUntil.toString().split('.').first)} (local time). Reopen JamJot for an updated sheet after this time. A saved or printed copy does not update automatically.</p>$body</body></html>''';
}
