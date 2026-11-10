import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_service.dart';

/// One instrument a student plays and who teaches it (JJ-043-C).
/// [instruction] is 'caregiver' (a caregiver teaches it, or no teacher yet)
/// or 'teacher'. A teacher is either linked ([enrollmentId], already on
/// JamJot) or just named by the caregiver ([teacherName]).
class StudentInstrument {
  const StudentInstrument({
    required this.id,
    required this.studentId,
    required this.instrument,
    required this.instruction,
    this.enrollmentId,
    this.teacherName,
    this.teacherKnownAs,
  });

  factory StudentInstrument.fromRow(Map<String, dynamic> r) => StudentInstrument(
        id: r['id'] as String,
        studentId: r['student_id'] as String,
        instrument: r['instrument'] as String,
        instruction: r['instruction'] as String? ?? 'caregiver',
        enrollmentId: r['enrollment_id'] as String?,
        teacherName: r['teacher_name'] as String?,
        teacherKnownAs: r['teacher_known_as'] as String?,
      );

  final String id;
  final String studentId;
  final String instrument;
  final String instruction;
  final String? enrollmentId;
  final String? teacherName;
  final String? teacherKnownAs;

  bool get taughtByTeacher => instruction == 'teacher';

  /// Short line for lists: who teaches this instrument.
  String whoTeaches({String? linkedTeacherName}) {
    if (!taughtByTeacher) return 'A caregiver teaches this';
    final known = (teacherKnownAs ?? '').trim();
    final name = (linkedTeacherName ?? teacherName ?? '').trim();
    if (known.isNotEmpty && name.isNotEmpty && known != name) {
      return '$name (known as $known)';
    }
    final label = known.isNotEmpty ? known : name;
    return label.isEmpty ? 'A teacher instructs' : label;
  }
}

final studentInstrumentsProvider = FutureProvider.autoDispose
    .family<List<StudentInstrument>, String>((ref, studentId) async {
  final rows = await JamJotBackend.client
      .from('student_instruments')
      .select()
      .eq('student_id', studentId)
      .order('created_at');
  return [for (final r in rows) StudentInstrument.fromRow(r)];
});

/// What to store when a caregiver chooses who teaches an instrument.
/// A linked teacher wins over typed names; no teacher means a caregiver.
Map<String, dynamic> whoTeachesFields({
  required bool teacherInstructs,
  String? enrollmentId,
  String? teacherName,
  String? teacherKnownAs,
}) {
  if (!teacherInstructs) {
    return {
      'instruction': 'caregiver',
      'enrollment_id': null,
      'teacher_name': null,
      'teacher_known_as': null,
    };
  }
  String? clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  if (enrollmentId != null) {
    return {
      'instruction': 'teacher',
      'enrollment_id': enrollmentId,
      'teacher_name': null,
      'teacher_known_as': clean(teacherKnownAs),
    };
  }
  return {
    'instruction': 'teacher',
    'enrollment_id': null,
    'teacher_name': clean(teacherName),
    'teacher_known_as': clean(teacherKnownAs),
  };
}

Future<void> saveWhoTeaches(String rowId, Map<String, dynamic> fields) async {
  final rows = await JamJotBackend.client
      .from('student_instruments')
      .update(fields)
      .eq('id', rowId)
      .select('id');
  if (rows.isEmpty) throw StateError('not allowed');
}

/// Adds the instrument to the student (the database keeps the student's own
/// instrument list in step) and returns the new row.
Future<StudentInstrument> addStudentInstrument(
    String studentId, String instrument) async {
  final row = await JamJotBackend.client
      .from('student_instruments')
      .insert({
        'student_id': studentId,
        'instrument': instrument,
        'created_by': JamJotBackend.client.auth.currentUser?.id,
      })
      .select()
      .single();
  return StudentInstrument.fromRow(row);
}

Future<void> removeStudentInstrument(String rowId) async {
  await JamJotBackend.client
      .from('student_instruments')
      .delete()
      .eq('id', rowId);
}

/// Saves the daily/weekly goals for a caregiver-run instrument: updates the
/// newest family-run lesson for it, or starts one if there is none yet.
Future<void> saveFamilyGoals(
    {required String studentId,
    required String instrument,
    required int days,
    required int minutes}) async {
  final rows = await JamJotBackend.client
      .from('lessons')
      .select('id, week_start')
      .eq('student_id', studentId)
      .isFilter('enrollment_id', null)
      .ilike('instrument', instrument)
      .order('week_start', ascending: false, nullsFirst: false)
      .order('created_at', ascending: false);
  final today = DateTime.now();
  String? lessonId;
  for (final r in rows) {
    final ws = r['week_start'] as String?;
    if (ws == null || !DateTime.parse(ws).isAfter(today)) {
      lessonId = r['id'] as String;
      break;
    }
  }
  if (lessonId != null) {
    final updated = await JamJotBackend.client
        .from('lessons')
        .update({'goal_days': days, 'goal_minutes': minutes})
        .eq('id', lessonId)
        .select('id');
    if (updated.isEmpty) throw StateError('not allowed');
  } else {
    await JamJotBackend.client.from('lessons').insert({
      'student_id': studentId,
      'created_by': JamJotBackend.client.auth.currentUser!.id,
      'title': 'This week',
      'instrument': instrument,
      'goal_days': days,
      'goal_minutes': minutes,
    });
  }
}

/// Caregiver's rule for the shared "days this week" count.
Future<void> saveStreakRule(String studentId, String rule) async {
  final rows = await JamJotBackend.client
      .from('students')
      .update({'streak_rule': rule})
      .eq('id', studentId)
      .select('id');
  if (rows.isEmpty) throw StateError('not allowed');
}

/// Result of entering a teacher's permanent code.
class ConnectResult {
  const ConnectResult.ok(this.teacherName) : error = null;
  const ConnectResult.failed(this.error) : teacherName = null;
  final String? teacherName;
  final String? error;
  bool get ok => error == null;
}

Future<ConnectResult> connectTeacherByCode(
    {required String code,
    required String studentId,
    required String instrument}) async {
  final res = await JamJotBackend.client.rpc('connect_teacher_by_code', params: {
    'p_code': code,
    'p_student_id': studentId,
    'p_instrument': instrument,
  });
  final m = Map<String, dynamic>.from(res as Map);
  return m['ok'] == true
      ? ConnectResult.ok(m['teacher_name'] as String?)
      : ConnectResult.failed(m['error'] as String? ?? 'Could not connect.');
}

/// Creates an invitation for a teacher who isn't on JamJot yet; returns the
/// link to send them.
Future<String> createTeacherInvite(
    {required String studentId,
    required String instrument,
    String? teacherName,
    String? knownAs,
    String? studentLastInitial}) async {
  final token = await JamJotBackend.client.rpc('create_teacher_invite', params: {
    'p_student_id': studentId,
    'p_instrument': instrument,
    'p_teacher_name': teacherName ?? '',
    'p_known_as': knownAs ?? '',
    'p_last_initial': studentLastInitial ?? '',
  });
  return 'https://jamjot.app/invite?token=$token';
}

/// A teacher's permanent code. Only the teacher and caregivers of their
/// active students can read it.
final teacherCodeProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, teacherId) async {
  final rows = await JamJotBackend.client
      .from('teacher_codes')
      .select('code')
      .eq('teacher_id', teacherId);
  return rows.isEmpty ? null : rows.first['code'] as String?;
});

/// What a teacher sees on an invite link before accepting (works signed out).
/// Null = not a teacher invite. {status: ok|used|expired, student, instrument}.
Future<Map<String, dynamic>?> teacherInvitePreview(String token) async {
  try {
    final res = await JamJotBackend.client
        .rpc('teacher_invite_preview', params: {'p_token': token});
    return res == null ? null : Map<String, dynamic>.from(res as Map);
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>> acceptTeacherInvite(String token) async {
  final res = await JamJotBackend.client
      .rpc('accept_teacher_invite', params: {'p_token': token});
  return Map<String, dynamic>.from(res as Map);
}
