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
        {
          ...(r['students'] as Map<String, dynamic>),
          'is_primary': r['is_primary']
        },
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

/// Which instrument tab the practice page is on (JJ-043-C). Null = the
/// kid's first instrument. Reset whenever a different kid takes over.
final activeInstrumentProvider = StateProvider<String?>((ref) => null);

/// True while a practice recording is running, so the instrument tabs
/// can't be switched out from under it.
final practiceLiveProvider = StateProvider<bool>((ref) => false);

/// A student's first instrument, looked up by id (works in caregiver view,
/// where no kid is "active").
String? firstInstrumentOf(Ref ref, String studentId) {
  for (final k in ref.read(myStudentsProvider).valueOrNull ?? const []) {
    if (k['id'] == studentId) return instrumentsOf(k).firstOrNull;
  }
  return instrumentsOf(ref.read(activeStudentProvider)).firstOrNull;
}

/// The instruments a student plays, in order.
List<String> instrumentsOf(Map<String, dynamic>? student) =>
    ((student?['instruments'] as List?) ?? const []).whereType<String>().toList();

/// The instrument the practice page shows for [student]: the chosen tab if
/// they still play it, otherwise their first one (null if they have none).
String? practiceInstrumentFor(Map<String, dynamic>? student, String? chosen) {
  final all = instrumentsOf(student);
  if (all.isEmpty) return null;
  if (chosen != null) {
    for (final i in all) {
      if (i.toLowerCase() == chosen.toLowerCase()) return i;
    }
  }
  return all.first;
}

/// Does a lesson/session row (instrument may be null from an older app
/// version) belong to [instrument]? Rows without one count as the first.
bool belongsToInstrument(
    String? rowInstrument, String? instrument, String? firstInstrument) {
  if (instrument == null) return true;
  final r = (rowInstrument ?? firstInstrument)?.toLowerCase();
  return r == instrument.toLowerCase();
}

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
  final rows = await query
      .order('week_start', ascending: false, nullsFirst: false)
      .order('created_at', ascending: false);
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
final currentLessonProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>(
        (ref, studentId) => _loadCurrentLesson(ref, studentId, null, null));

/// The same combined practice, for one instrument only (the practice page's
/// instrument tabs). Key: (student id, instrument).
final currentInstrumentLessonProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, (String, String?)>((ref, key) {
  final first = firstInstrumentOf(ref, key.$1);
  return _loadCurrentLesson(ref, key.$1, key.$2, first);
});

Future<Map<String, dynamic>?> _loadCurrentLesson(Ref ref, String studentId,
    String? instrument, String? firstInstrument) async {
  final rows = await JamJotBackend.client
      .from('lessons')
      .select('*, assignments(*)')
      .eq('student_id', studentId)
      .order('week_start', ascending: false, nullsFirst: false)
      .order('created_at', ascending: false);
  if (rows.isEmpty) return null;
  final today = DateTime.now();
  final newestPerConnection = <String, Map<String, dynamic>>{};
  for (final r in rows) {
    final ws = r['week_start'] as String?;
    if (ws != null && DateTime.parse(ws).isAfter(today)) continue;
    if (!belongsToInstrument(
        r['instrument'] as String?, instrument, firstInstrument)) {
      continue;
    }
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
      ..sort((a, b) =>
          (a['order_idx'] as int? ?? 0).compareTo(b['order_idx'] as int? ?? 0));
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
}

/// After finishing practice on [key.$2], the next of the kid's instruments
/// (in order, wrapping around) that has a lesson and whose daily minutes
/// goal isn't met yet. Null when there's nothing to nudge toward.
final nextInstrumentProvider = FutureProvider.autoDispose
    .family<String?, (String, String?)>((ref, key) async {
  final (sid, current) = key;
  final all = instrumentsOf(ref.read(activeStudentProvider));
  if (all.length < 2) return null;
  final start =
      all.indexWhere((i) => i.toLowerCase() == (current ?? '').toLowerCase());
  for (var k = 1; k < all.length; k++) {
    final inst = all[((start < 0 ? 0 : start) + k) % all.length];
    final lesson = await ref.read(currentInstrumentLessonProvider((sid, inst)).future);
    if (lesson == null) continue;
    final goal = (lesson['goal_minutes'] as num?)?.toInt() ?? 15;
    final progress =
        await ref.read(weeklyInstrumentProgressProvider((sid, inst)).future);
    if ((progress['today_minutes'] ?? 0) < goal) return inst;
  }
  return null;
});

/// A student's last and next scheduled lessons (from the calendar).
final lessonScheduleProvider = FutureProvider.autoDispose
    .family<Map<String, Map<String, dynamic>?>, String>((ref, studentId) async {
  final rows = await JamJotBackend.client
      .from('event_students')
      .select('calendar_events(kind, title, starts_at, teachers(display_name))')
      .eq('student_id', studentId);
  final now = DateTime.now();
  Map<String, dynamic>? last;
  Map<String, dynamic>? next;
  DateTime? lastAt;
  DateTime? nextAt;
  for (final r in rows) {
    final ev = r['calendar_events'] as Map<String, dynamic>?;
    if (ev == null || ev['kind'] != 'lesson') continue;
    final at = DateTime.parse(ev['starts_at'] as String).toLocal();
    if (at.isBefore(now)) {
      if (lastAt == null || at.isAfter(lastAt)) {
        lastAt = at;
        last = ev;
      }
    } else {
      if (nextAt == null || at.isBefore(nextAt)) {
        nextAt = at;
        next = ev;
      }
    }
  }
  return {'last': last, 'next': next};
});

/// Practice progress this week: {'days': n, 'today_minutes': m}.
final weeklyProgressProvider =
    FutureProvider.family<Map<String, int>, String>((ref, studentId) async {
  final base = await _weeklyProgress(studentId, null, null);
  // Several instruments: the shared "days this week" follows the caregiver's
  // rule (students.streak_rule) instead of counting any practice at all.
  Map<String, dynamic>? kid;
  for (final k in await ref.watch(myStudentsProvider.future)) {
    if (k['id'] == studentId) kid = k;
  }
  final instruments = instrumentsOf(kid);
  if (kid == null || instruments.length < 2) return base;
  final goals = <String, int>{};
  for (final i in instruments) {
    final lesson =
        await ref.watch(currentInstrumentLessonProvider((studentId, i)).future);
    if (lesson != null) {
      goals[i.toLowerCase()] = (lesson['goal_minutes'] as num?)?.toInt() ?? 15;
    }
  }
  if (goals.isEmpty) return base;
  final days = await _sharedPracticeDays(studentId, goals,
      all: kid['streak_rule'] == 'all', first: instruments.first);
  return {...base, 'days': days};
});

/// Days this week that count under the shared rule: 'any' = some instrument
/// with a lesson met its daily minutes goal that day; 'all' = every one did.
Future<int> _sharedPracticeDays(String studentId, Map<String, int> goalsByInstrument,
    {required bool all, required String first}) async {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  final rows = await JamJotBackend.client
      .from('sessions')
      .select('started_at, total_seconds, instrument')
      .eq('student_id', studentId)
      .gte('started_at', monday.toUtc().toIso8601String());
  final secs = <String, Map<String, int>>{}; // day -> instrument -> seconds
  for (final r in rows) {
    final dt = DateTime.parse(r['started_at'] as String).toLocal();
    final day = '${dt.year}-${dt.month}-${dt.day}';
    final inst = ((r['instrument'] as String?) ?? first).toLowerCase();
    final m = secs.putIfAbsent(day, () => {});
    m[inst] = (m[inst] ?? 0) + ((r['total_seconds'] as num?)?.toInt() ?? 0);
  }
  return sharedDaysCount(secs, goalsByInstrument, all: all);
}

/// The counting rule on its own (kept separate so it can be tested).
int sharedDaysCount(Map<String, Map<String, int>> secondsByDay,
    Map<String, int> goalsByInstrument,
    {required bool all}) {
  var count = 0;
  for (final perInstrument in secondsByDay.values) {
    final met = [
      for (final e in goalsByInstrument.entries)
        (perInstrument[e.key] ?? 0) ~/ 60 >= e.value
    ];
    if (met.isEmpty) continue;
    if (all ? met.every((m) => m) : met.any((m) => m)) count++;
  }
  return count;
}

/// True when a kid with 2+ instruments has met every instrument's daily
/// minutes goal today (the "Full Band" badge).
final fullBandTodayProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, studentId) async {
  Map<String, dynamic>? kid;
  for (final k in await ref.watch(myStudentsProvider.future)) {
    if (k['id'] == studentId) kid = k;
  }
  final instruments = instrumentsOf(kid);
  if (instruments.length < 2) return false;
  var withLesson = 0;
  for (final i in instruments) {
    final lesson =
        await ref.watch(currentInstrumentLessonProvider((studentId, i)).future);
    if (lesson == null) continue;
    withLesson++;
    final goal = (lesson['goal_minutes'] as num?)?.toInt() ?? 15;
    final p = await ref.watch(weeklyInstrumentProgressProvider((studentId, i)).future);
    if ((p['today_minutes'] ?? 0) < goal) return false;
  }
  return withLesson >= 2;
});

/// This week's progress on one instrument only. Key: (student id, instrument).
final weeklyInstrumentProgressProvider =
    FutureProvider.family<Map<String, int>, (String, String?)>((ref, key) {
  final first = firstInstrumentOf(ref, key.$1);
  return _weeklyProgress(key.$1, key.$2, first);
});

Future<Map<String, int>> _weeklyProgress(
    String studentId, String? instrument, String? firstInstrument) async {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  final rows = await JamJotBackend.client
      .from('sessions')
      .select('id, started_at, total_seconds, instrument')
      .eq('student_id', studentId)
      .gte('started_at', monday.toUtc().toIso8601String());
  final days = <String>{};
  final sessionSeconds = <String, int>{};
  var todaySeconds = 0;
  final todayKey = '${now.year}-${now.month}-${now.day}';
  for (final r in rows) {
    final secs = (r['total_seconds'] as num?)?.toInt() ?? 0;
    if (secs <= 0) continue;
    if (!belongsToInstrument(
        r['instrument'] as String?, instrument, firstInstrument)) {
      continue;
    }
    final dt = DateTime.parse(r['started_at'] as String).toLocal();
    final key = '${dt.year}-${dt.month}-${dt.day}';
    days.add(key);
    if (key == todayKey) {
      todaySeconds += secs;
      sessionSeconds['session/${r['id']}'] = secs;
    }
  }
  return {
    'days': days.length,
    'today_minutes': todaySeconds ~/ 60,
    'today_seconds': todaySeconds,
    ...sessionSeconds
  };
}

/// Everyone caring for one kid, with their permission grants.
final kidGuardianshipsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, studentId) async {
  final rows = await JamJotBackend.client
      .from('guardianships')
      .select()
      .eq('student_id', studentId)
      .order('is_primary', ascending: false);
  return rows.cast<Map<String, dynamic>>();
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
/// Every assignment the creator could re-use, from all three places they
/// live — standalone saved assignments, assignments inside saved lesson
/// templates, and assignments already given on live lessons — deduped by
/// title+book. The create-lesson search looks through this pool
/// (founder bug report 2026-11-05: searching found nothing because only
/// the standalone table, usually empty, was searched).
/// Files assignment payloads into the creator's standalone library — minus
/// anything student-specific — skipping ones already there (title+book).
/// Called whenever a lesson is created (founder-directed 2026-11-05).
Future<void> rememberAssignmentsInLibrary(
    List<Map<String, dynamic>> payloads) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null || payloads.isEmpty) return;
  try {
    final existing = await JamJotBackend.client
        .from('saved_assignments')
        .select('payload')
        .eq('owner_id', uid);
    String keyOf(Map p) =>
        '${(p['title'] ?? '').toString().trim().toLowerCase()}|${(p['book'] ?? '').toString().trim().toLowerCase()}';
    final seen = {
      for (final r in existing) keyOf((r['payload'] as Map?) ?? const {}),
    };
    final rows = <Map<String, dynamic>>[];
    for (final p in payloads) {
      final title = (p['title'] as String? ?? '').trim();
      if (title.isEmpty || !seen.add(keyOf(p))) continue;
      rows.add({
        'owner_id': uid,
        'payload': {
          'title': title,
          'book': (p['book'] as String? ?? '').trim(),
          'pages': (p['pages'] as String? ?? '').trim(),
          'note':
              (p['note'] as String? ?? p['song_note'] as String? ?? '').trim(),
          'score_id': p['score_id'],
          if (p['kind'] != null) 'kind': p['kind'],
          if (p['suggested_minutes'] != null)
            'suggested_minutes': p['suggested_minutes'],
        },
      });
    }
    if (rows.isNotEmpty) {
      await JamJotBackend.client.from('saved_assignments').insert(rows);
    }
  } catch (_) {
    // Library filing is best-effort; the lesson itself already saved.
  }
}

/// A create-lesson draft built from a student's existing lesson, student
/// details stripped — for "assign this again next week" (founder-directed
/// 2026-11-05). The dialog lets the creator remove, add and create
/// assignments before saving.
Map<String, dynamic> draftFromLesson(Map<String, dynamic> lesson) {
  final base = DateTime.tryParse(lesson['week_start'] as String? ?? '') ??
      DateTime.now();
  final nextWeek = base.add(const Duration(days: 7));
  return {
    'lesson_title': lesson['title'],
    'lesson_note': lesson['lesson_note'] ?? '',
    'goal_days': lesson['goal_days'],
    'goal_minutes': lesson['goal_minutes'],
    'lesson_date':
        '${nextWeek.year.toString().padLeft(4, '0')}-${nextWeek.month.toString().padLeft(2, '0')}-${nextWeek.day.toString().padLeft(2, '0')}',
    'assignments': [
      for (final a in (lesson['assignments'] as List? ?? const []))
        {
          'title': (a as Map)['title'],
          'book': a['book'] ?? '',
          'pages': a['pages'] ?? '',
          'note': a['song_note'] ?? a['note'] ?? '',
          'score_id': a['score_id'],
          if (a['kind'] != null) 'kind': a['kind'],
          if (a['suggested_minutes'] != null)
            'suggested_minutes': a['suggested_minutes'],
        },
    ],
  };
}

final assignmentSearchPoolProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null) return [];
  final seen = <String>{};
  final pool = <Map<String, dynamic>>[];
  void add(Map<String, dynamic> payload) {
    final title = (payload['title'] as String? ?? '').trim();
    if (title.isEmpty) return;
    final key =
        '${title.toLowerCase()}|${(payload['book'] as String? ?? '').trim().toLowerCase()}';
    if (!seen.add(key)) return;
    pool.add(payload);
  }

  final saved = await ref.watch(savedAssignmentsProvider.future);
  for (final a in saved) {
    add(Map<String, dynamic>.from(a['payload'] as Map? ?? {}));
  }
  final lessons = await ref.watch(savedLessonsProvider.future);
  for (final l in lessons) {
    for (final a
        in ((l['payload'] as Map?)?['assignments'] as List? ?? const [])) {
      add(Map<String, dynamic>.from(a as Map));
    }
  }
  try {
    final live = await JamJotBackend.client
        .from('assignments')
        .select(
            'title, song_note, book, pages, kind, score_id, suggested_minutes, lessons!inner(created_by)')
        .eq('lessons.created_by', uid)
        .order('created_at', ascending: false)
        .limit(300);
    for (final a in live.cast<Map<String, dynamic>>()) {
      add({
        'title': a['title'],
        'book': a['book'] ?? '',
        'pages': a['pages'] ?? '',
        'note': a['song_note'] ?? '',
        'score_id': a['score_id'],
        if (a['kind'] != null) 'kind': a['kind'],
        if (a['suggested_minutes'] != null)
          'suggested_minutes': a['suggested_minutes'],
      });
    }
  } catch (_) {
    // Live assignments are a bonus source; the pool works without them.
  }
  return pool;
});

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
      .select(
          'calendar_events(kind, starts_at, title, teachers(finalize_hour))')
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
    final cutoff =
        DateTime(dayBefore.year, dayBefore.month, dayBefore.day, finalizeHour);
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
