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
