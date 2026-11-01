import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/supabase_service.dart';
import '../../theme/jamjot_theme.dart';
import 'calendar_screen.dart' show calendarEventsProvider;

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// How many weeks ahead the calendar is filled from a weekly schedule.
const _weeksAhead = 12;

/// Set (or change/remove) the weekly lesson day & time for one student's
/// section — a teacher connection, or family-run practice. Saving fills the
/// next 12 weeks of lessons into everyone's calendars; saving again moves
/// the future ones; removing clears the future ones. Past events and
/// individually changed/cancelled ones are left alone.
Future<void> editWeeklySchedule(BuildContext context, WidgetRef ref,
    {required Map<String, dynamic> kid,
    String? enrollmentId,
    required String sectionLabel}) async {
  final client = JamJotBackend.client;
  final uid = client.auth.currentUser!.id;
  final sid = kid['id'] as String;
  final name = kid['display_name'] as String? ?? 'Student';

  var query =
      client.from('lesson_schedules').select().eq('student_id', sid);
  query = enrollmentId == null
      ? query.isFilter('enrollment_id', null)
      : query.eq('enrollment_id', enrollmentId);
  final rows = await query.limit(1);
  final existing =
      rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  if (!context.mounted) return;

  var weekday = (existing?['weekday'] as num?)?.toInt() ?? 1;
  var atMinutes =
      (existing?['at_minutes'] as num?)?.toInt() ?? (15 * 60 + 30);
  var duration = (existing?['duration_minutes'] as num?)?.toInt() ?? 30;

  final action = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text("$name's weekly lesson"),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sectionLabel,
                    style: const TextStyle(
                        color: JamJotColors.inkSoft,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (var d = 1; d <= 7; d++)
                    ChoiceChip(
                      label: Text(_weekdays[d - 1].substring(0, 3)),
                      selected: weekday == d,
                      selectedColor: JamJotColors.blueberryTint,
                      onSelected: (_) => setState(() => weekday = d),
                    ),
                ]),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                          hour: atMinutes ~/ 60, minute: atMinutes % 60),
                    );
                    if (picked != null) {
                      setState(() =>
                          atMinutes = picked.hour * 60 + picked.minute);
                    }
                  },
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(TimeOfDay(
                          hour: atMinutes ~/ 60, minute: atMinutes % 60)
                      .format(context)),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 6, children: [
                  for (final m in [30, 45, 60])
                    ChoiceChip(
                      label: Text('$m min'),
                      selected: duration == m,
                      selectedColor: JamJotColors.blueberryTint,
                      onSelected: (_) => setState(() => duration = m),
                    ),
                ]),
                const SizedBox(height: 10),
                Text(
                  'Saving fills the next $_weeksAhead weeks of lessons into the calendar (and moves the upcoming ones if the time changed).',
                  style: const TextStyle(
                      fontSize: 12, color: JamJotColors.inkSoft),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop('remove'),
              child: const Text('Remove schedule',
                  style: TextStyle(color: JamJotColors.recording)),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('save'),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (action == null) return;

  final nowIso = DateTime.now().toUtc().toIso8601String();
  try {
    if (action == 'remove') {
      await client
          .from('calendar_events')
          .delete()
          .eq('schedule_id', existing!['id'])
          .eq('owner_id', uid)
          .gte('starts_at', nowIso);
      await client
          .from('lesson_schedules')
          .delete()
          .eq('id', existing['id']);
    } else {
      // Save the schedule row.
      String scheduleId;
      if (existing != null) {
        scheduleId = existing['id'] as String;
        await client.from('lesson_schedules').update({
          'weekday': weekday,
          'at_minutes': atMinutes,
          'duration_minutes': duration,
        }).eq('id', scheduleId);
      } else {
        final row = await client
            .from('lesson_schedules')
            .insert({
              'student_id': sid,
              'enrollment_id': enrollmentId,
              'weekday': weekday,
              'at_minutes': atMinutes,
              'duration_minutes': duration,
              'created_by': uid,
            })
            .select()
            .single();
        scheduleId = row['id'] as String;
      }
      // Clear this schedule's future events, then fill the weeks ahead.
      await client
          .from('calendar_events')
          .delete()
          .eq('schedule_id', scheduleId)
          .eq('owner_id', uid)
          .gte('starts_at', nowIso);
      final now = DateTime.now();
      var first = DateTime(now.year, now.month, now.day,
          atMinutes ~/ 60, atMinutes % 60);
      while (first.weekday != weekday || !first.isAfter(now)) {
        first = first.add(const Duration(days: 1));
      }
      for (var w = 0; w < _weeksAhead; w++) {
        final starts = first.add(Duration(days: 7 * w));
        final event = await client
            .from('calendar_events')
            .insert({
              'owner_id': uid,
              'kind': 'lesson',
              'title': 'Lesson',
              'notes': sectionLabel,
              'starts_at': starts.toUtc().toIso8601String(),
              'ends_at': starts
                  .add(Duration(minutes: duration))
                  .toUtc()
                  .toIso8601String(),
              'schedule_id': scheduleId,
            })
            .select()
            .single();
        await client
            .from('event_students')
            .insert({'event_id': event['id'], 'student_id': sid});
      }
    }
    ref.invalidate(calendarEventsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'remove'
              ? 'Weekly lessons removed from the calendar.'
              : 'Weekly lessons on the calendar: ${_weekdays[weekday - 1]}s at ${TimeOfDay(hour: atMinutes ~/ 60, minute: atMinutes % 60).format(context)}. 📅')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Could not update the weekly schedule — try again?')));
    }
  }
}

/// The schedule summary for a section, used on cards ("Mondays at 3:30 PM").
Future<String?> weeklyScheduleSummary(
    BuildContext context, String studentId, String? enrollmentId) async {
  var query = JamJotBackend.client
      .from('lesson_schedules')
      .select()
      .eq('student_id', studentId);
  query = enrollmentId == null
      ? query.isFilter('enrollment_id', null)
      : query.eq('enrollment_id', enrollmentId);
  final rows = await query.limit(1);
  if (rows.isEmpty) return null;
  final r = rows.first;
  final at = (r['at_minutes'] as num).toInt();
  if (!context.mounted) return null;
  return '${_weekdays[(r['weekday'] as num).toInt() - 1]}s at ${TimeOfDay(hour: at ~/ 60, minute: at % 60).format(context)}';
}
