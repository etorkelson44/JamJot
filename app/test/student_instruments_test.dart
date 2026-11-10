import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/services/student_instruments.dart';

// Fictional data only.
StudentInstrument _row(Map<String, dynamic> over) =>
    StudentInstrument.fromRow({
      'id': 'a',
      'student_id': 's',
      'instrument': 'Violin',
      'instruction': 'caregiver',
      ...over,
    });

void main() {
  group('whoTeachesFields', () {
    test('caregiver teaches: clears every teacher field', () {
      expect(whoTeachesFields(teacherInstructs: false, teacherName: 'X'), {
        'instruction': 'caregiver',
        'enrollment_id': null,
        'teacher_name': null,
        'teacher_known_as': null,
      });
    });

    test('linked teacher wins over a typed name', () {
      final f = whoTeachesFields(
          teacherInstructs: true,
          enrollmentId: 'e1',
          teacherName: 'Typed',
          teacherKnownAs: ' Ms. F ');
      expect(f['enrollment_id'], 'e1');
      expect(f['teacher_name'], isNull);
      expect(f['teacher_known_as'], 'Ms. F');
    });

    test('new teacher keeps trimmed name and known-as; blanks become null', () {
      final f = whoTeachesFields(
          teacherInstructs: true, teacherName: ' Ada Fictional ', teacherKnownAs: '  ');
      expect(f['instruction'], 'teacher');
      expect(f['teacher_name'], 'Ada Fictional');
      expect(f['teacher_known_as'], isNull);
    });
  });

  group('StudentInstrument.whoTeaches', () {
    test('caregiver', () {
      expect(_row({}).whoTeaches(), 'A caregiver teaches this');
    });
    test('named teacher with a different known-as', () {
      final i = _row({
        'instruction': 'teacher',
        'teacher_name': 'Ada Fictional',
        'teacher_known_as': 'Ms. Ada'
      });
      expect(i.whoTeaches(), 'Ada Fictional (known as Ms. Ada)');
    });
    test('linked teacher name comes from the connection', () {
      final i = _row({'instruction': 'teacher', 'enrollment_id': 'e'});
      expect(i.whoTeaches(linkedTeacherName: 'Sam Example'), 'Sam Example');
    });
    test('teacher with no details yet', () {
      expect(_row({'instruction': 'teacher'}).whoTeaches(), 'A teacher instructs');
    });
  });
}
