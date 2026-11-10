import 'package:supabase_flutter/supabase_flutter.dart';

/// Read today's latest resumable session across both deployed schema versions.
/// SELECT * includes manual_override_seconds only after the integrity migration;
/// filtering returned rows keeps older databases usable without hiding errors or
/// accidentally reopening a corrected session after that migration is applied.
Future<Map<String, dynamic>?> latestResumablePracticeSession(
    SupabaseClient client, String studentId, DateTime now,
    {bool Function(Map<String, dynamic> row)? where}) async {
  final dayStart = DateTime(now.year, now.month, now.day);
  final dayEnd = DateTime(now.year, now.month, now.day + 1);
  const pageSize = 50;
  for (var offset = 0;; offset += pageSize) {
    final rows = await client
        .from('sessions')
        .select('*, session_segments(*)')
        .eq('student_id', studentId)
        .eq('source', 'app')
        .gte('started_at', dayStart.toUtc().toIso8601String())
        .lt('started_at', dayEnd.toUtc().toIso8601String())
        .order('started_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + pageSize - 1);
    for (final row in rows) {
      if (row['manual_override_seconds'] == null &&
          (where == null || where(row))) {
        return row;
      }
    }
    if (rows.length < pageSize) return null;
  }
}
