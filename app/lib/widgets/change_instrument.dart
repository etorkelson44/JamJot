import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../state/app_state.dart';
import '../theme/jamjot_theme.dart';
import 'instrument_picker.dart';

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
      title: 'Change instrument',
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
