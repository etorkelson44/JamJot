import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// Hash used for kid PINs and the grown-up app PIN. Not a password system —
/// real security is the account password; PINs only gate profile switching.
String hashPin(String pin) =>
    sha256.convert(utf8.encode('jamjot:$pin')).toString();

/// The signed-in grown-up's profile row.
final myProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null) return null;
  return JamJotBackend.client
      .from('profiles')
      .select()
      .eq('id', uid)
      .maybeSingle();
});

/// Students this grown-up is a guardian of (with their guardianship row).
final myStudentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null) return [];
  final rows = await JamJotBackend.client
      .from('guardianships')
      .select('is_primary, students(*)')
      .eq('profile_id', uid);
  return [
    for (final r in rows)
      if (r['students'] != null)
        {...(r['students'] as Map<String, dynamic>), 'is_primary': r['is_primary']},
  ];
});

/// This grown-up's teacher row, if they teach.
final myTeacherProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null) return null;
  final rows = await JamJotBackend.client
      .from('teachers')
      .select()
      .eq('profile_id', uid);
  return rows.isEmpty ? null : rows.first as Map<String, dynamic>;
});

/// Who is currently "driving" the app: null = the grown-up, otherwise a
/// student row from myStudentsProvider.
final activeStudentProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

/// A student's berry balance (sum of their ledger).
final berryBalanceProvider =
    FutureProvider.family<int, String>((ref, studentId) async {
  final rows = await JamJotBackend.client
      .from('berry_ledger')
      .select('amount')
      .eq('student_id', studentId);
  var total = 0;
  for (final r in rows) {
    total += (r['amount'] as num).toInt();
  }
  return total;
});

/// A student's permanent fan total.
final fanTotalProvider =
    FutureProvider.family<int, String>((ref, studentId) async {
  final rows = await JamJotBackend.client
      .from('fan_ledger')
      .select('amount')
      .eq('student_id', studentId);
  var total = 0;
  for (final r in rows) {
    total += (r['amount'] as num).toInt();
  }
  return total;
});

/// A kid's active teacher connections (one per teacher × instrument).
final kidEnrollmentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, studentId) async {
  final rows = await JamJotBackend.client
      .from('enrollments')
      .select('id, instrument, teachers(display_name, profile_id)')
      .eq('student_id', studentId)
      .eq('status', 'active');
  return rows.cast<Map<String, dynamic>>();
});

/// The newest arrived lesson for one connection ('family' = no teacher).
final lessonForEnrollmentProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, (String, String?)>((ref, key) async {
  final (studentId, enrollmentId) = key;
  var query = JamJotBackend.client
      .from('lessons')
      .select('*, assignments(*)')
      .eq('student_id', studentId);
  query = enrollmentId == null
      ? query.isFilter('enrollment_id', null)
      : query.eq('enrollment_id', enrollmentId);
  final rows =
      await query.order('created_at', ascending: false).limit(10);
  final today = DateTime.now();
  for (final r in rows) {
    final ws = r['week_start'] as String?;
    if (ws == null || !DateTime.parse(ws).isAfter(today)) {
      final lesson = Map<String, dynamic>.from(r);
      final assignments = (lesson['assignments'] as List? ?? [])
          .cast<Map<String, dynamic>>()
        ..sort((a, b) => (a['order_idx'] as int? ?? 0)
            .compareTo(b['order_idx'] as int? ?? 0));
      lesson['assignments'] = assignments;
      return lesson;
    }
  }
  return null;
});

/// The kid's combined practice for today: the newest arrived lesson from
/// EACH connection (every teacher, plus family-run), merged into one list.
/// Goals use the highest asked of the kid; assignments carry their source.
final currentLessonProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, studentId) async {
  final rows = await JamJotBackend.client
      .from('lessons')
      .select('*, assignments(*)')
      .eq('student_id', studentId)
      .order('created_at', ascending: false)
      .limit(25);
  if (rows.isEmpty) return null;
  final today = DateTime.now();
  final newestPerConnection = <String, Map<String, dynamic>>{};
  for (final r in rows) {
    final ws = r['week_start'] as String?;
    if (ws != null && DateTime.parse(ws).isAfter(today)) continue;
    final key = (r['enrollment_id'] as String?) ?? 'family';
    newestPerConnection.putIfAbsent(key, () => Map<String, dynamic>.from(r));
  }
  if (newestPerConnection.isEmpty) return null;

  // Label each lesson's songs with where they came from.
  final enrollments = await ref.watch(kidEnrollmentsProvider(studentId).future);
  final labels = {
    for (final e in enrollments)
      e['id'] as String:
          (e['teachers'] as Map?)?['display_name'] as String? ?? 'Teacher',
  };

  final merged = <Map<String, dynamic>>[];
  var goalDays = 0;
  var goalMinutes = 0;
  final notes = <String>[];
  for (final entry in newestPerConnection.entries) {
    final l = entry.value;
    final source = entry.key == 'family' ? null : labels[entry.key];
    final assignments = (l['assignments'] as List? ?? [])
        .cast<Map<String, dynamic>>()
      ..sort((a, b) => (a['order_idx'] as int? ?? 0)
          .compareTo(b['order_idx'] as int? ?? 0));
    for (final a in assignments) {
      merged.add({...a, if (source != null) 'source': source});
    }
    final gd = (l['goal_days'] as num?)?.toInt() ?? 0;
    final gm = (l['goal_minutes'] as num?)?.toInt() ?? 0;
    if (gd > goalDays) goalDays = gd;
    if (gm > goalMinutes) goalMinutes = gm;
    final note = (l['lesson_note'] as String?)?.trim() ?? '';
    if (note.isNotEmpty) notes.add(source == null ? note : '$source: $note');
  }
  final first = newestPerConnection.values.first;
  return {
    ...first,
    'assignments': merged,
    'goal_days': goalDays == 0 ? 4 : goalDays,
    'goal_minutes': goalMinutes == 0 ? 15 : goalMinutes,
    'lesson_note': notes.join(' • '),
  };
});

/// Practice progress this week: {'days': n, 'today_minutes': m}.
final weeklyProgressProvider =
    FutureProvider.family<Map<String, int>, String>((ref, studentId) async {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  final rows = await JamJotBackend.client
      .from('sessions')
      .select('started_at, total_seconds')
      .eq('student_id', studentId)
      .gte('started_at', monday.toUtc().toIso8601String());
  final days = <String>{};
  var todaySeconds = 0;
  final todayKey = '${now.year}-${now.month}-${now.day}';
  for (final r in rows) {
    final secs = (r['total_seconds'] as num?)?.toInt() ?? 0;
    if (secs <= 0) continue;
    final dt = DateTime.parse(r['started_at'] as String).toLocal();
    final key = '${dt.year}-${dt.month}-${dt.day}';
    days.add(key);
    if (key == todayKey) todaySeconds += secs;
  }
  return {'days': days.length, 'today_minutes': todaySeconds ~/ 60};
});

/// Chats I belong to: one per enrollment (teacher + student + permitted
/// caregivers). Caregivers without messaging permission see nothing.
final myChatsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null) return [];
  final enrollments = await JamJotBackend.client
      .from('enrollments')
      .select(
          'id, instrument, status, students(id, display_name), teachers(id, display_name, profile_id)')
      .eq('status', 'active');
  final guards = await JamJotBackend.client
      .from('guardianships')
      .select('student_id, is_primary, can_message')
      .eq('profile_id', uid);
  final byStudent = {for (final g in guards) g['student_id'] as String: g};
  final activeKid = ref.watch(activeStudentProvider);

  final chats = <Map<String, dynamic>>[];
  for (final e in enrollments) {
    final student = e['students'] as Map<String, dynamic>?;
    final teacher = e['teachers'] as Map<String, dynamic>?;
    if (student == null || teacher == null) continue;
    final sid = student['id'] as String;
    final iAmTeacher = teacher['profile_id'] == uid;
    final guard = byStudent[sid];
    final iMayMessage = iAmTeacher ||
        (guard != null &&
            (guard['is_primary'] == true || guard['can_message'] == true));
    if (!iMayMessage) continue;
    // In kid mode, only the active kid's chats show.
    if (activeKid != null && activeKid['id'] != sid) continue;
    chats.add({
      'enrollment_id': e['id'],
      'student_name': student['display_name'],
      'teacher_name': teacher['display_name'],
      'teacher_profile_id': teacher['profile_id'],
      'instrument': e['instrument'],
      'i_am_primary': guard?['is_primary'] == true,
    });
  }
  return chats;
});

/// An invite token waiting to be redeemed after sign-in.
String? pendingInviteToken;

/// Students enrolled with me as their teacher.
final teacherStudentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final teacher = await ref.watch(myTeacherProvider.future);
  if (teacher == null) return [];
  final rows = await JamJotBackend.client
      .from('enrollments')
      .select('id, instrument, status, students(*)')
      .eq('teacher_id', teacher['id'])
      .eq('status', 'active');
  return [
    for (final r in rows)
      if (r['students'] != null)
        {
          ...(r['students'] as Map<String, dynamic>),
          'enrollment_id': r['id'],
          'enrollment_instrument': r['instrument'],
        },
  ];
});

/// My uploaded music files (scores bucket rows).
final libraryScoresProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null) return [];
  final rows = await JamJotBackend.client
      .from('scores')
      .select()
      .eq('owner_id', uid)
      .order('created_at', ascending: false);
  return rows.cast<Map<String, dynamic>>();
});

/// My saved assignment templates.
final savedAssignmentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null) return [];
  final rows = await JamJotBackend.client
      .from('saved_assignments')
      .select()
      .eq('owner_id', uid)
      .order('created_at', ascending: false);
  return rows.cast<Map<String, dynamic>>();
});

/// My saved lesson templates.
final savedLessonsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null) return [];
  final rows = await JamJotBackend.client
      .from('saved_lessons')
      .select()
      .eq('owner_id', uid)
      .order('created_at', ascending: false);
  return rows.cast<Map<String, dynamic>>();
});

/// Loose search: every typed word must appear somewhere in the text.
bool looseMatch(String query, String text) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final t = text.toLowerCase();
  return q.split(RegExp(r'\s+')).every(t.contains);
}

/// Is practice closed right now because a lesson is coming up and the
/// teacher's weekly sheet has been finalized? (Night-before cutoff.)
/// Returns null when open, or info about the lesson when closed.
final practiceCutoffProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, studentId) async {
  final now = DateTime.now();
  final rows = await JamJotBackend.client
      .from('event_students')
      .select('calendar_events(kind, starts_at, title, teachers(finalize_hour))')
      .eq('student_id', studentId);
  for (final r in rows) {
    final ev = r['calendar_events'] as Map<String, dynamic>?;
    if (ev == null || ev['kind'] != 'lesson') continue;
    final startsAt = DateTime.parse(ev['starts_at'] as String).toLocal();
    if (startsAt.isBefore(now)) continue;
    final finalizeHour =
        ((ev['teachers'] as Map?)?['finalize_hour'] as num?)?.toInt() ?? 21;
    final dayBefore = DateTime(startsAt.year, startsAt.month, startsAt.day)
        .subtract(const Duration(days: 1));
    final cutoff = DateTime(
        dayBefore.year, dayBefore.month, dayBefore.day, finalizeHour);
    if (!now.isBefore(cutoff) && now.isBefore(startsAt)) {
      return {'lesson_at': startsAt, 'title': ev['title']};
    }
  }
  return null;
});

/// Remember the active kid across app restarts (best effort).
Future<void> rememberActiveStudent(String? studentId) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null) return;
  try {
    await JamJotBackend.client
        .from('profiles')
        .update({'last_active_student': studentId}).eq('id', uid);
  } catch (_) {/* non-fatal */}
}
