import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../state/app_state.dart';
import '../theme/jamjot_theme.dart';
import '../services/student_instruments.dart';
import 'instrument_picker.dart';
import 'who_teaches_dialog.dart';

/// Adults can fix a kid's instrument after the profile is made (JJ-036-C).
/// The database decides who may: the primary guardian changes the kid's
/// instrument list; the primary guardian or the enrolled teacher changes
/// the instrument on a teacher connection.

Future<List<String>?> _pickDialog(BuildContext context,
    {required String title,
    required List<String> start,
    required bool multiple,
    String? Function(List<String>)? check}) {
  var value = [...start];
  String? error;
  return showDialog<List<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InstrumentPicker(
                  value: value,
                  multiple: multiple,
                  onChanged: (v) => setState(() {
                    value = v;
                    error = null;
                  }),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style: const TextStyle(color: JamJotColors.recording)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (value.isEmpty) {
                setState(() => error = 'Pick at least one instrument.');
                return;
              }
              final problem = check?.call(value);
              if (problem != null) {
                setState(() => error = problem);
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

void _toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

/// The kid's own instrument list (students.instruments). Primary guardian.
Future<void> changeKidInstruments(
    BuildContext context, WidgetRef ref, Map<String, dynamic> kid) async {
  final start = ((kid['instruments'] as List?) ?? const [])
      .whereType<String>()
      .toList();
  final picked = await _pickDialog(context,
      title: 'What does ${kid['display_name']} play?',
      start: start,
      multiple: true);
  if (picked == null || !context.mounted) return;
  try {
    final rows = await JamJotBackend.client
        .from('students')
        .update({'instruments': picked})
        .eq('id', kid['id'] as String)
        .select('id');
    if (rows.isEmpty) throw StateError('not allowed');
    ref.invalidate(myStudentsProvider);
    final active = ref.read(activeStudentProvider);
    if (active != null && active['id'] == kid['id']) {
      ref.read(activeStudentProvider.notifier).state = {
        ...active,
        'instruments': picked
      };
    }
    if (context.mounted) _toast(context, 'Instruments updated.');
  } catch (_) {
    if (context.mounted) {
      _toast(context,
          'Could not save just now. Only the primary caregiver can change this.');
    }
  }
}

/// The instrument on one teacher connection (enrollments.instrument).
/// Primary guardian or the enrolled teacher.
Future<void> changeEnrollmentInstrument(
  BuildContext context,
  WidgetRef ref, {
  required String enrollmentId,
  required String studentId,
  required String? current,
  String? studentName,
}) async {
  final picked = await _pickDialog(context,
      title: 'Edit instrument',
      start: [if (current != null && current.isNotEmpty) current],
      multiple: false);
  if (picked == null || !context.mounted) return;
  final next = picked.first;
  if (next == current) return;
  try {
    final rows = await JamJotBackend.client
        .from('enrollments')
        .update({'instrument': next})
        .eq('id', enrollmentId)
        .select('id');
    if (rows.isEmpty) throw StateError('not allowed');
    ref.invalidate(kidEnrollmentsProvider(studentId));
    ref.invalidate(myChatsProvider);
    ref.invalidate(teacherStudentsProvider);
    if (context.mounted) _toast(context, 'Instrument changed to $next.');
  } on PostgrestException catch (e) {
    if (!context.mounted) return;
    // uniq_active_enrollment: one active connection per student, teacher
    // and instrument.
    _toast(
        context,
        e.code == '23505'
            ? '${studentName ?? 'This student'} already has $next lessons with this teacher.'
            : 'Could not save just now. Please try again.');
  } catch (_) {
    if (context.mounted) {
      _toast(context,
          'Could not save just now. Only the primary caregiver or the teacher can change this.');
    }
  }
}

/// Caregiver adds one more instrument for a kid, then says who teaches it
/// (JJ-043-C). Uses the same instrument search as everywhere else.
Future<void> addInstrumentFlow(
    BuildContext context, WidgetRef ref, Map<String, dynamic> kid) async {
  final studentId = kid['id'] as String;
  final name = kid['display_name'] as String? ?? 'your student';
  final have = ((kid['instruments'] as List?) ?? const [])
      .whereType<String>()
      .map((s) => s.toLowerCase())
      .toSet();
  final picked = await _pickDialog(context,
      title: 'Add an instrument for $name',
      start: const [],
      multiple: false,
      check: (v) => have.contains(v.first.toLowerCase())
          ? '$name already plays ${v.first}.'
          : null);
  if (picked == null || !context.mounted) return;
  try {
    final item = await addStudentInstrument(studentId, picked.first);
    ref.invalidate(myStudentsProvider);
    ref.invalidate(studentInstrumentsProvider(studentId));
    final active = ref.read(activeStudentProvider);
    if (active != null && active['id'] == studentId) {
      ref.read(activeStudentProvider.notifier).state = {
        ...active,
        'instruments': [...((kid['instruments'] as List?) ?? const []), picked.first],
      };
    }
    if (!context.mounted) return;
    await showWhoTeachesDialog(context, ref,
        studentId: studentId, studentName: name, item: item);
  } catch (_) {
    if (context.mounted) {
      _toast(context,
          'Could not add that just now. Only a caregiver can change this.');
    }
  }
}

/// Take an instrument off a kid's list. Lessons already made for it stay.
Future<void> removeInstrumentFlow(BuildContext context, WidgetRef ref,
    Map<String, dynamic> kid, StudentInstrument item) async {
  final studentId = kid['id'] as String;
  final name = kid['display_name'] as String? ?? 'This student';
  if (!isInstrumentHidden(kid, item.instrument) &&
      instrumentsOf(kid).length <= 1) {
    _toast(context,
        '$name needs at least one instrument showing. Add another one first.');
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete ${item.instrument}?'),
      content: Text(
          'Deleting takes ${item.instrument} off $name\'s list for good, so it won\'t show up anywhere.\n\nJust taking a break? Choose "Hide for now" instead. Everything stays saved and comes back when you show it again.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await removeStudentInstrument(item.id);
    ref.invalidate(myStudentsProvider);
    ref.invalidate(studentInstrumentsProvider(studentId));
    final active = ref.read(activeStudentProvider);
    if (active != null && active['id'] == studentId) {
      ref.read(activeStudentProvider.notifier).state = {
        ...active,
        'instruments': [
          for (final i in (active['instruments'] as List? ?? const []))
            if ((i as String).toLowerCase() != item.instrument.toLowerCase()) i
        ],
      };
    }
    if (context.mounted) _toast(context, '${item.instrument} removed.');
  } catch (_) {
    if (context.mounted) {
      _toast(context, 'Could not remove that just now. Please try again.');
    }
  }
}

/// Hide an instrument for now (e.g. a break). Explains the difference from deleting.
Future<void> hideInstrumentFlow(BuildContext context, WidgetRef ref,
    Map<String, dynamic> kid, StudentInstrument item) async {
  final studentId = kid['id'] as String;
  final name = kid['display_name'] as String? ?? 'This student';
  if (instrumentsOf(kid).length <= 1) {
    _toast(context,
        '$name needs at least one instrument showing. Add another one first.');
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Hide ${item.instrument} for now?'),
      content: Text(
          'While it\'s hidden, ${item.instrument} and its lessons, assignments and goals disappear from $name\'s profile, and it doesn\'t count toward rewards.\n\n'
          'Nothing is deleted. Tap "Show again" later and everything comes back just as it was.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hide for now')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await hideInstrumentRpc(studentId, item.instrument);
    await _refreshAfterHide(ref, studentId);
  } catch (_) {
    if (context.mounted) {
      _toast(context, 'Could not hide that just now. Only a caregiver can change this.');
    }
  }
}

Future<void> showInstrumentAgainFlow(BuildContext context, WidgetRef ref,
    Map<String, dynamic> kid, StudentInstrument item) async {
  final studentId = kid['id'] as String;
  try {
    await showInstrumentAgainRpc(studentId, item.instrument);
    await _refreshAfterHide(ref, studentId);
    if (context.mounted) {
      _toast(context, '${item.instrument} is back, with everything saved from before.');
    }
  } catch (_) {
    if (context.mounted) {
      _toast(context, 'Could not show that just now. Please try again.');
    }
  }
}

Future<void> _refreshAfterHide(WidgetRef ref, String studentId) async {
  ref.invalidate(myStudentsProvider);
  ref.invalidate(studentInstrumentsProvider(studentId));
  ref.invalidate(weeklyProgressProvider(studentId));
  ref.invalidate(currentLessonProvider(studentId));
  try {
    final fresh = await ref.read(myStudentsProvider.future);
    final active = ref.read(activeStudentProvider);
    if (active != null && active['id'] == studentId) {
      for (final k in fresh) {
        if (k['id'] == studentId) {
          ref.read(activeStudentProvider.notifier).state = {...active, ...k};
        }
      }
    }
  } catch (_) {}
}
