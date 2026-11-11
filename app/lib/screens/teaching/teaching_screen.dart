import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/student_instruments.dart';
import '../../widgets/invite_message_dialog.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/jamjot_card.dart';
import '../../widgets/log_practice.dart' show logOfflinePractice;
import '../calendar/weekly_lesson.dart' show editWeeklySchedule;
import '../library/library_screen.dart' show showCreateLessonDialog;
import '../../widgets/maestro_loader.dart';
import '../../widgets/instrument_icon.dart';
import '../../widgets/instrument_picker.dart';
import '../../widgets/change_instrument.dart';

/// Pending change requests on events this teacher owns.
final changeRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await JamJotBackend.client
      .from('event_change_requests')
      .select(
          '*, calendar_events(id, title, starts_at, ends_at, status, event_students(student_id))')
      .eq('status', 'pending')
      .order('created_at', ascending: false);
  final uid = JamJotBackend.client.auth.currentUser?.id;
  // RLS already limits to mine-or-requested-by-me; keep only mine-to-answer.
  return rows
      .cast<Map<String, dynamic>>()
      .where((r) => r['requested_by'] != uid)
      .toList();
});

/// The teacher's home base: invite families, see the roster, teach.
class TeachingScreen extends ConsumerWidget {
  const TeachingScreen({super.key});

  Future<void> _inviteFamily(BuildContext context, WidgetRef ref,
      Map<String, dynamic> teacher) async {
    final name = TextEditingController();
    final first = (teacher['instruments'] as List?)?.firstOrNull as String?;
    var instrument = <String>[if (first != null && first.isNotEmpty) first];
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: const Text('Invite a family'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: "Student's first name (optional)"),
            ),
            const SizedBox(height: 14),
            StatefulBuilder(
              builder: (context, setState) => InstrumentPicker(
                value: instrument,
                multiple: false,
                onChanged: (v) => setState(() => instrument = v),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final uid = JamJotBackend.client.auth.currentUser!.id;
              final row = await JamJotBackend.client
                  .from('invitations')
                  .insert({
                    'kind': 'enrollment',
                    'created_by': uid,
                    'teacher_id': teacher['id'],
                    'studio_id': teacher['studio_id'],
                    'instrument':
                        instrument.isEmpty ? 'Music' : instrument.first,
                    'preset_grants': {
                      if (name.text.trim().isNotEmpty)
                        'student_name': name.text.trim(),
                    },
                  })
                  .select()
                  .single();
              if (context.mounted) Navigator.of(context).pop(row);
            },
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            child: const Text('Create invite'),
          ),
        ],
      ),
    );
    if (created == null || !context.mounted) return;
    final link =
        'https://jamjot.app/#/invite?token=${created['token']}';
    final student = name.text.trim();
    final who = student.isEmpty ? 'your student' : student;
    final teacherName = (teacher['display_name'] as String?) ?? 'Your teacher';
    await showInviteMessageDialog(context,
        link: link,
        recipientName: student.isEmpty ? 'the family' : '$student\'s family',
        subject: 'Join $who on JamJot',
        message: '''Hi!

I\'m using JamJot for my music lessons. It helps $who\'s home practice really count: it listens while they play, so only real playing time is counted, and it keeps them motivated with little rewards for finishing assigned songs. Each week you\'ll see what was assigned, and I\'ll be able to see (and hear!) what was practiced before each lesson.

Tap this link to join. It works whether or not you already have JamJot:
$link

(The link is just for you. It works once and expires in 30 days.)

— $teacherName''');
  }

  /// Each teacher has one standing code families can use anytime —
  /// as text, a link, or a QR code at the studio door.
  Future<void> _showMyCode(BuildContext context, WidgetRef ref,
      Map<String, dynamic> teacher) async {
    final uid = JamJotBackend.client.auth.currentUser!.id;
    // Find (or mint) the standing, reusable invitation.
    final existing = await JamJotBackend.client
        .from('invitations')
        .select()
        .eq('created_by', uid)
        .eq('single_use', false)
        .limit(1);
    Map<String, dynamic> invite;
    if (existing.isNotEmpty) {
      invite = existing.first;
    } else {
      invite = await JamJotBackend.client
          .from('invitations')
          .insert({
            'kind': 'enrollment',
            'created_by': uid,
            'teacher_id': teacher['id'],
            'studio_id': teacher['studio_id'],
            'instrument':
                (teacher['instruments'] as List?)?.firstOrNull ?? 'Music',
            'single_use': false,
          })
          .select()
          .single();
    }
    if (!context.mounted) return;
    final code = invite['token'] as String;
    final link = 'https://jamjot.app/#/invite?token=$code';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: const Text('My teacher code'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Families can scan this, tap the link, or type the code into JamJot to connect with you — it never expires and works for every student.'),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: JamJotColors.ink, width: 2),
                ),
                child: QrImageView(
                  data: link,
                  size: 190,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText('Code: $code',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied!')));
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy link'),
            style: FilledButton.styleFrom(minimumSize: const Size(130, 44)),
          ),
        ],
      ),
    );
  }

  /// Approve a family's cancel request: cancel the lesson (kept on the
  /// calendar, struck through) with a note everyone sees.
  Future<void> _approveCancel(
      BuildContext context, WidgetRef ref, Map<String, dynamic> r) async {
    final ev = r['calendar_events'] as Map<String, dynamic>?;
    if (ev == null) return;
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text('Cancel "${ev['title']}"?'),
        content: TextField(
          controller: note,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              labelText: 'Note for the family (optional)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Back')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            child: const Text('Cancel the lesson'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await JamJotBackend.client.from('calendar_events').update({
        'status': 'cancelled',
        'status_note': [
          "At the family's request",
          if (note.text.trim().isNotEmpty) note.text.trim(),
        ].join(' — '),
      }).eq('id', ev['id']);
      await JamJotBackend.client
          .from('event_change_requests')
          .update({'status': 'handled'}).eq('id', r['id']);
      ref.invalidate(changeRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Cancelled. You can offer a make-up from the same request, or schedule one anytime.')));
      }
    } catch (_) {}
  }

  /// Offer a make-up (for a cancel) or move the lesson (for a reschedule):
  /// pick a date & time, with a note attached for everyone.
  Future<void> _offerNewTime(
      BuildContext context, WidgetRef ref, Map<String, dynamic> r) async {
    final ev = r['calendar_events'] as Map<String, dynamic>?;
    if (ev == null) return;
    final isMakeup = r['request_kind'] == 'cancel';
    final oldStart = DateTime.parse(ev['starts_at'] as String).toLocal();
    final oldEnd = ev['ends_at'] == null
        ? null
        : DateTime.parse(ev['ends_at'] as String).toLocal();
    final duration = oldEnd == null
        ? const Duration(minutes: 30)
        : oldEnd.difference(oldStart);
    final day = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day == null || !context.mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(oldStart));
    if (time == null || !context.mounted) return;
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text(isMakeup ? 'Offer a make-up lesson' : 'Move the lesson'),
        content: TextField(
          controller: note,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              labelText: 'Note for the family (optional)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Back')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            child: Text(isMakeup ? 'Offer it' : 'Move it'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final starts =
        DateTime(day.year, day.month, day.day, time.hour, time.minute);
    try {
      if (isMakeup) {
        // Cancel the original (if not already) and add a make-up lesson
        // for the same students.
        if (ev['status'] != 'cancelled') {
          await JamJotBackend.client.from('calendar_events').update({
            'status': 'cancelled',
            'status_note': "At the family's request — make-up offered",
          }).eq('id', ev['id']);
        }
        final uid = JamJotBackend.client.auth.currentUser!.id;
        final makeup = await JamJotBackend.client
            .from('calendar_events')
            .insert({
              'owner_id': uid,
              'kind': 'extra_lesson',
              'title': 'Make-up lesson',
              'notes': note.text.trim().isEmpty
                  ? 'Make-up for ${ev['title']}'
                  : note.text.trim(),
              'starts_at': starts.toUtc().toIso8601String(),
              'ends_at':
                  starts.add(duration).toUtc().toIso8601String(),
            })
            .select()
            .single();
        for (final es in ((ev['event_students'] as List?) ?? [])
            .cast<Map<String, dynamic>>()) {
          await JamJotBackend.client.from('event_students').insert({
            'event_id': makeup['id'],
            'student_id': es['student_id'],
          });
        }
      } else {
        await JamJotBackend.client.from('calendar_events').update({
          'starts_at': starts.toUtc().toIso8601String(),
          'ends_at': starts.add(duration).toUtc().toIso8601String(),
          'status': 'scheduled',
          'status_note': [
            'Moved from ${DateFormat('EEE, MMM d • h:mm a').format(oldStart)}',
            if (note.text.trim().isNotEmpty) note.text.trim(),
          ].join(' — '),
        }).eq('id', ev['id']);
      }
      await JamJotBackend.client
          .from('event_change_requests')
          .update({'status': 'handled'}).eq('id', r['id']);
      ref.invalidate(changeRequestsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not update the calendar — try again?')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(myTeacherProvider).valueOrNull;
    final roster = ref.watch(teacherStudentsProvider).valueOrNull ?? [];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My teaching'),
        leading: BackButton(onPressed: () => context.go('/home')),
      ),
      body: SafeArea(
        child: teacher == null
            ? const Center(child: MaestroLoader())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(teacher['display_name'] as String? ?? '',
                      style: text.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  InstrumentList((teacher['instruments'] as List?) ?? const [],
                      iconSize: 24,
                      style: text.bodyMedium
                          ?.copyWith(color: JamJotColors.inkSoft)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _inviteFamily(context, ref, teacher),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Invite a family'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _showMyCode(context, ref, teacher),
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('My teacher code (QR & link)'),
                  ),
                  Consumer(builder: (context, ref, _) {
                    final code = ref
                        .watch(teacherCodeProvider(teacher['id'] as String))
                        .valueOrNull;
                    if (code == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(JamJotShape.chipRadius),
                          side: JamJotShape.border,
                        ),
                        title: Text('Your family code: $code',
                            style: text.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        subtitle: const Text(
                            'Give it to a family when you choose; they enter it to connect to you. You can change it any time, and families already connected stay connected.'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Copy code',
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: code));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Code copied!')));
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Change my code',
                              icon: const Icon(Icons.autorenew, size: 20),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Change your family code?'),
                                    content: const Text(
                                        'You\'ll get a brand-new code. Families already connected to you stay connected and don\'t need to do anything.\n\nThe old code stops working, so anyone who hasn\'t entered it yet will need the new one.'),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel')),
                                      FilledButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Change code')),
                                    ],
                                  ),
                                );
                                if (ok != true || !context.mounted) return;
                                try {
                                  final fresh = await rotateTeacherCode(teacher['id'] as String);
                                  ref.invalidate(teacherCodeProvider(teacher['id'] as String));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Your new code is $fresh')));
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                        content: Text('Could not change the code just now. Please try again.')));
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  Consumer(builder: (context, ref, _) {
                    final requests =
                        ref.watch(changeRequestsProvider).valueOrNull ?? [];
                    if (requests.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Text('Change requests',
                            style: text.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        for (final r in requests) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: JamJotColors.marigoldTint,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: JamJotColors.ink, width: 2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${(r['request_kind'] as String?)?.toUpperCase() ?? ''} — ${(r['calendar_events'] as Map?)?['title'] ?? 'Event'}',
                                  style: text.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700),
                                ),
                                if ((r['note'] as String?)?.isNotEmpty ==
                                    true)
                                  Text(r['note'] as String,
                                      style: text.bodySmall),
                                Wrap(spacing: 4, children: [
                                  if (r['request_kind'] == 'cancel' &&
                                      (r['calendar_events']
                                              as Map?)?['status'] !=
                                          'cancelled')
                                    TextButton(
                                      onPressed: () =>
                                          _approveCancel(context, ref, r),
                                      child: const Text('Cancel the lesson…'),
                                    ),
                                  if (r['request_kind'] == 'reschedule' ||
                                      r['request_kind'] == 'cancel')
                                    TextButton(
                                      onPressed: () =>
                                          _offerNewTime(context, ref, r),
                                      child: Text(r['request_kind'] ==
                                              'cancel'
                                          ? 'Offer a make-up…'
                                          : 'Pick a new time…'),
                                    ),
                                  TextButton(
                                    onPressed: () async {
                                      await JamJotBackend.client
                                          .from('event_change_requests')
                                          .update({'status': 'handled'}).eq(
                                              'id', r['id']);
                                      ref.invalidate(changeRequestsProvider);
                                    },
                                    child: const Text('Mark handled'),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    );
                  }),
                  const SizedBox(height: 20),
                  Text('My students',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (roster.isEmpty)
                    Text(
                      'No students yet — send your first invite and the family appears here the moment they accept.',
                      style: text.bodyMedium
                          ?.copyWith(color: JamJotColors.inkSoft),
                    )
                  else
                    for (final s in roster) ...[
                      JamJotCard(
                        emoji: (s['display_name'] as String).isEmpty
                            ? '?'
                            : (s['display_name'] as String)[0].toUpperCase(),
                        tint: JamJotColors.neutral,
                        title: s['display_name'] as String,
                        extra: s['enrollment_instrument'] == null
                            ? null
                            : InstrumentLabel(
                                s['enrollment_instrument'] as String,
                                iconSize: 22,
                                style: text.bodySmall),
                        trailing: TextButton(
                          onPressed: () => changeEnrollmentInstrument(
                              context, ref,
                              enrollmentId: s['enrollment_id'] as String,
                              studentId: s['id'] as String,
                              current: s['enrollment_instrument'] as String?,
                              studentName: s['display_name'] as String?),
                          child: const Text('Change'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => showCreateLessonDialog(
                                context, ref,
                                student: s,
                                enrollmentId:
                                    s['enrollment_id'] as String?),
                            child: const Text('Assign lesson'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.go(
                                '/history?student=${s['id']}&name=${Uri.encodeComponent(s['display_name'] as String)}'),
                            child: const Text('History'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => editWeeklySchedule(context, ref,
                                kid: s,
                                enrollmentId:
                                    s['enrollment_id'] as String?,
                                sectionLabel:
                                    '${s['enrollment_instrument'] ?? 'Lessons'} with ${teacher?['display_name'] ?? 'me'}'),
                            child: const Text('Weekly time'),
                          ),
                        ),
                      ]),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 34)),
                          onPressed: () =>
                              logOfflinePractice(context, ref, kid: s),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                              'Log practice done without the app'),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                ],
              ),
      ),
    );
  }
}
