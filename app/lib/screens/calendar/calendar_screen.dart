import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../models/calendar_entry.dart';
import '../../widgets/calendar_views.dart';

/// All rows are still restricted by the existing server-side visibility rules.
final calendarEventsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
        (ref) => readCalendarPages((from, to) async {
              final rows = await JamJotBackend.client
                  .from('calendar_events')
                  .select(
                      '*, event_students(student_id, students(display_name)), teachers(display_name)')
                  .order('starts_at')
                  .order('id')
                  .range(from, to);
              return rows;
            }));

final assignedLessonsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
        (ref) => readCalendarPages((from, to) async {
              final rows = await JamJotBackend.client
                  .from('lessons')
                  .select(
                      'id, title, week_start, student_id, event_id, students(display_name)')
                  .order('week_start')
                  .order('id')
                  .range(from, to);
              return rows;
            }));

const _kindEmoji = {
  'lesson': '🎒',
  'extra_lesson': '🎒',
  'performance': '🎭',
  'event': '🎪',
  'family': '🏡',
};

/// Keep student accents inside the current profile palette.
Color studentColor(BuildContext context, String id) => Color.lerp(
    Theme.of(context).colorScheme.primary,
    Theme.of(context).colorScheme.onSurface,
    (id.hashCode.abs() % 4) * .16)!;

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.readOnly = false});
  final bool readOnly;
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  /// The private subscribe link for Google/Apple/Skylight/Cozi.
  Future<void> _syncDialog(BuildContext context) async {
    final client = JamJotBackend.client;
    final uid = client.auth.currentUser!.id;
    var rows = await client.from('calendar_feeds').select().limit(1);
    if (rows.isEmpty) {
      rows = [
        await client
            .from('calendar_feeds')
            .insert({'profile_id': uid})
            .select()
            .single()
      ];
    }
    final link =
        '${JamJotBackend.url}/functions/v1/calendar-feed?token=${rows.first['token']}';
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: const Text('Sync to other calendars'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Subscribe any calendar app to this private link and JamJot lessons & events appear there (updates flow in automatically):'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: JamJotColors.blueberryTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(link,
                      style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied! 📋')));
                    }
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy the link'),
                ),
                const SizedBox(height: 12),
                const Text('Where to paste it:',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                    '• Google Calendar: Other calendars → + → From URL\n'
                    '• Apple Calendar: File → New Calendar Subscription (or Settings → Accounts → Add Subscribed Calendar on iPhone)\n'
                    '• Skylight: Settings → Add Calendar → iCal/ICS link\n'
                    '• Cozi: Settings → Linked Calendars → Subscribe by URL',
                    style: TextStyle(fontSize: 12.5)),
                const SizedBox(height: 10),
                Text(
                  'This link is private but anyone who has it can see your JamJot calendar — share it only with calendar apps you trust.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .75)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(calendarEventsProvider);
    final lessons = ref.watch(assignedLessonsProvider);
    final activeKid = ref.watch(activeStudentProvider);
    final teacher = ref.watch(myTeacherProvider).valueOrNull;
    final students = ref.watch(myStudentsProvider).valueOrNull ?? [];
    final uid = JamJotBackend.client.auth.currentUser?.id;
    final theme = Theme.of(context);
    final loading = (events.isLoading && !events.hasValue) ||
        (lessons.isLoading && !lessons.hasValue);
    final failed = events.hasError || lessons.hasError;
    return SafeArea(
        child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth < 600 ? 16 : 24,
                    20,
                    constraints.maxWidth < 600 ? 16 : 24,
                    32),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1440),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Calendar',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 16),
                              if (activeKid == null && !widget.readOnly) ...[
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  if (teacher != null)
                                    FilledButton.icon(
                                        onPressed: () => _scheduleDialog(
                                            context, ref, teacher: teacher),
                                        icon: const Icon(Icons.add),
                                        label: const Text(
                                            'Schedule lesson / event')),
                                  if (students.isNotEmpty)
                                    OutlinedButton.icon(
                                        onPressed: () => _familyEventDialog(
                                            context, ref, students),
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add family event')),
                                ]),
                                if (students.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                      'Family events stay private to your family — teachers and studios never see them.',
                                      style: theme.textTheme.bodySmall),
                                ],
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                        onPressed: () => _syncDialog(context),
                                        icon: const Icon(Icons.sync, size: 18),
                                        label: const Text(
                                            'Sync to Google / Apple / Skylight / Cozi…'))),
                                const SizedBox(height: 16),
                              ],
                              if (loading)
                                const Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Center(
                                        child: CircularProgressIndicator(
                                            semanticsLabel:
                                                'Loading calendar')))
                              else if (failed)
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 32),
                                    child: Column(children: [
                                      const Text(
                                          'Your calendar could not be loaded. Please try again.'),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                          onPressed: () {
                                            ref.invalidate(
                                                calendarEventsProvider);
                                            ref.invalidate(
                                                assignedLessonsProvider);
                                          },
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Try again')),
                                    ]))
                              else
                                CalendarViews(
                                    entries: calendarEntries(
                                        events: events.valueOrNull ?? [],
                                        lessons: lessons.valueOrNull ?? [],
                                        studentId: activeKid?['id'] as String?),
                                    detailBuilder: (context, entry) => entry
                                            .isLesson
                                        ? _AssignedLessonCard(
                                            lesson: entry.record)
                                        : _EventCard(
                                            event: entry.record,
                                            readOnly: widget.readOnly,
                                            isMine: uid != null &&
                                                entry.record['owner_id'] == uid,
                                            isKidView: widget.readOnly ||
                                                activeKid != null)),
                            ]))))));
  }

  // ------------------------------------------------ teacher scheduling
  Future<void> _scheduleDialog(BuildContext context, WidgetRef ref,
      {required Map<String, dynamic> teacher}) async {
    final roster = await ref.read(teacherStudentsProvider.future);
    if (!context.mounted) return;
    final title = TextEditingController(text: 'Lesson');
    final notes = TextEditingController();
    final weeks = TextEditingController(text: '1');
    var kind = 'lesson';
    var date = DateTime.now().add(const Duration(days: 1));
    var time = const TimeOfDay(hour: 15, minute: 30);
    var minutes = 30;
    final picked = <String>{};
    const kinds = {
      'lesson': 'Lesson',
      'extra_lesson': 'Extra lesson',
      'performance': 'Performance',
      'event': 'Studio event',
    };

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
            side: JamJotShape.border,
          ),
          title: const Text('Schedule'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final k in kinds.keys)
                      ChoiceChip(
                        label: Text(kinds[k]!),
                        selected: kind == k,
                        selectedColor: JamJotColors.blueberryTint,
                        onSelected: (_) => setState(() {
                          kind = k;
                          if (title.text == 'Lesson' ||
                              kinds.values.contains(title.text)) {
                            title.text = kinds[k]!;
                          }
                        }),
                      ),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    controller: title,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 1)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (d != null) setState(() => date = d);
                        },
                        icon: const Icon(Icons.event, size: 18),
                        label: Text(DateFormat('MMM d').format(date)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final t = await showTimePicker(
                              context: context, initialTime: time);
                          if (t != null) setState(() => time = t);
                        },
                        icon: const Icon(Icons.schedule, size: 18),
                        label: Text(time.format(context)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Text('Length: '),
                    for (final m in [30, 45, 60])
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text('$m min'),
                          selected: minutes == m,
                          selectedColor: JamJotColors.blueberryTint,
                          onSelected: (_) => setState(() => minutes = m),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 10),
                  const Text('Who is it for?',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  for (final s in roster)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(s['display_name'] as String),
                      value: picked.contains(s['id']),
                      onChanged: (v) => setState(() => v == true
                          ? picked.add(s['id'] as String)
                          : picked.remove(s['id'])),
                    ),
                  TextField(
                    controller: notes,
                    textCapitalization: TextCapitalization.sentences,
                    decoration:
                        const InputDecoration(labelText: 'Notes (optional)'),
                  ),
                  const SizedBox(height: 10),
                  if (kind == 'lesson')
                    TextField(
                      controller: weeks,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText:
                              'Repeat weekly for how many weeks? (1 = just once)'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed:
                  picked.isEmpty ? null : () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final uid = JamJotBackend.client.auth.currentUser!.id;
      final count = (int.tryParse(weeks.text.trim()) ?? 1).clamp(1, 26);
      for (var i = 0; i < (kind == 'lesson' ? count : 1); i++) {
        final startsAt =
            DateTime(date.year, date.month, date.day, time.hour, time.minute)
                .add(Duration(days: 7 * i));
        final ev = await JamJotBackend.client
            .from('calendar_events')
            .insert({
              'kind': kind,
              'title': title.text.trim(),
              'starts_at': startsAt.toUtc().toIso8601String(),
              'ends_at': startsAt
                  .add(Duration(minutes: minutes))
                  .toUtc()
                  .toIso8601String(),
              'owner_id': uid,
              'teacher_id': teacher['id'],
              'studio_id': teacher['studio_id'],
              'notes': notes.text.trim(),
            })
            .select()
            .single();
        for (final sid in picked) {
          await JamJotBackend.client
              .from('event_students')
              .insert({'event_id': ev['id'], 'student_id': sid});
        }
      }
      ref.invalidate(calendarEventsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Scheduled! 🎉')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not schedule just now — try again?')));
      }
    }
  }

  // ------------------------------------------------ family events
  Future<void> _familyEventDialog(BuildContext context, WidgetRef ref,
      List<Map<String, dynamic>> students) async {
    final title = TextEditingController();
    final notes = TextEditingController();
    var date = DateTime.now();
    var time = const TimeOfDay(hour: 17, minute: 0);
    final picked = <String>{for (final s in students) s['id'] as String};

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
            side: JamJotShape.border,
          ),
          title: const Text('Family event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'What is it? (e.g. Soccer, Grandma visit)'),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 1)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setState(() => date = d);
                      },
                      icon: const Icon(Icons.event, size: 18),
                      label: Text(DateFormat('MMM d').format(date)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final t = await showTimePicker(
                            context: context, initialTime: time);
                        if (t != null) setState(() => time = t);
                      },
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text(time.format(context)),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                const Text('Which kids?',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                for (final s in students)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(s['display_name'] as String),
                    value: picked.contains(s['id']),
                    onChanged: (v) => setState(() => v == true
                        ? picked.add(s['id'] as String)
                        : picked.remove(s['id'])),
                  ),
                TextField(
                  controller: notes,
                  textCapitalization: TextCapitalization.sentences,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty || !context.mounted) return;
    try {
      final uid = JamJotBackend.client.auth.currentUser!.id;
      final startsAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      final ev = await JamJotBackend.client
          .from('calendar_events')
          .insert({
            'kind': 'family',
            'title': title.text.trim(),
            'starts_at': startsAt.toUtc().toIso8601String(),
            'ends_at': startsAt
                .add(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
            'owner_id': uid,
            'notes': notes.text.trim(),
          })
          .select()
          .single();
      for (final sid in picked) {
        await JamJotBackend.client
            .from('event_students')
            .insert({'event_id': ev['id'], 'student_id': sid});
      }
      ref.invalidate(calendarEventsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Family event added! 🏡')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not add it just now — try again?')));
      }
    }
  }
}

/// A practice lesson pinned to its assign-on date, with the printable sheet
/// one tap away.
class _AssignedLessonCard extends StatelessWidget {
  const _AssignedLessonCard({required this.lesson});
  final Map<String, dynamic> lesson;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name =
        (lesson['students'] as Map?)?['display_name'] as String? ?? 'Student';
    final color = studentColor(context, lesson['student_id'] as String);
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('📚', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson['title'] as String? ?? 'New lesson',
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text('New practice lesson for $name',
                      style: text.bodySmall?.copyWith(color: color)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14)),
              onPressed: () => context.go(
                  '/lesson-sheet?student=${lesson['student_id']}&name=${Uri.encodeComponent(name)}'),
              icon: const Icon(Icons.print, size: 16),
              label: const Text('Lesson sheet'),
            ),
          ),
        ],
      ),
    ));
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard(
      {required this.event,
      required this.isMine,
      required this.isKidView,
      this.readOnly = false});

  final Map<String, dynamic> event;
  final bool isMine;
  final bool isKidView;
  final bool readOnly;

  Future<void> _requestChange(BuildContext context, WidgetRef ref) async {
    final note = TextEditingController();
    var kind = 'reschedule';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
            side: JamJotShape.border,
          ),
          title: const Text('Request a change'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 6, children: [
                for (final k in ['reschedule', 'cancel', 'other'])
                  ChoiceChip(
                    label: Text(k[0].toUpperCase() + k.substring(1)),
                    selected: kind == k,
                    selectedColor: JamJotColors.blueberryTint,
                    onSelected: (_) => setState(() => kind = k),
                  ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Tell the teacher what you need'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
              child: const Text('Send request'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final uid = JamJotBackend.client.auth.currentUser!.id;
      await JamJotBackend.client.from('event_change_requests').insert({
        'event_id': event['id'],
        'requested_by': uid,
        'request_kind': kind,
        'note': note.text.trim(),
        'status': 'pending',
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Request sent — the teacher will see it. 📨')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not send the request just now.')));
      }
    }
  }

  Future<void> _deleteEvent(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text('Remove "${event['title']}"?'),
        content: const Text('Everyone linked to it will stop seeing it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep it')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: JamJotColors.recording,
                minimumSize: const Size(96, 44)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await JamJotBackend.client
          .from('calendar_events')
          .delete()
          .eq('id', event['id']);
      ref.invalidate(calendarEventsProvider);
    } catch (_) {}
  }

  Future<String?> _askNote(BuildContext context, String title,
      {String button = 'Save'}) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration:
              const InputDecoration(labelText: 'Note for everyone (optional)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(c.text.trim()),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: Text(button),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelEvent(BuildContext context, WidgetRef ref) async {
    final note = await _askNote(context, 'Cancel "${event['title']}"?',
        button: 'Cancel the lesson');
    if (note == null) return;
    try {
      await JamJotBackend.client.from('calendar_events').update({
        'status': 'cancelled',
        'status_note': note.isEmpty ? null : note,
      }).eq('id', event['id']);
      ref.invalidate(calendarEventsProvider);
    } catch (_) {}
  }

  Future<void> _restoreEvent(BuildContext context, WidgetRef ref) async {
    try {
      await JamJotBackend.client.from('calendar_events').update({
        'status': 'scheduled',
        'status_note': null,
      }).eq('id', event['id']);
      ref.invalidate(calendarEventsProvider);
    } catch (_) {}
  }

  Future<void> _moveEvent(BuildContext context, WidgetRef ref) async {
    final oldStart = DateTime.parse(event['starts_at'] as String).toLocal();
    final oldEnd = event['ends_at'] == null
        ? null
        : DateTime.parse(event['ends_at'] as String).toLocal();
    final duration = oldEnd == null
        ? const Duration(minutes: 30)
        : oldEnd.difference(oldStart);
    final day = await showDatePicker(
      context: context,
      initialDate: oldStart,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day == null || !context.mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(oldStart));
    if (time == null || !context.mounted) return;
    final note = await _askNote(context, 'Reschedule "${event['title']}"',
        button: 'Move it');
    if (note == null) return;
    final starts =
        DateTime(day.year, day.month, day.day, time.hour, time.minute);
    try {
      await JamJotBackend.client.from('calendar_events').update({
        'starts_at': starts.toUtc().toIso8601String(),
        'ends_at': starts.add(duration).toUtc().toIso8601String(),
        'status': 'scheduled',
        'status_note': [
          'Moved from ${DateFormat('EEE, MMM d • h:mm a').format(oldStart)}',
          if (note.isNotEmpty) note,
        ].join(' — '),
      }).eq('id', event['id']);
      ref.invalidate(calendarEventsProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final kind = event['kind'] as String? ?? 'event';
    final cancelled =
        (event['status'] as String? ?? 'scheduled') == 'cancelled';
    final statusNote = (event['status_note'] as String?)?.trim() ?? '';
    final isFamily = kind == 'family';
    final start = DateTime.parse(event['starts_at'] as String).toLocal();
    final end = event['ends_at'] == null
        ? null
        : DateTime.parse(event['ends_at'] as String).toLocal();
    final teacherName = (event['teachers'] as Map?)?['display_name'] as String?;
    final kids =
        ((event['event_students'] as List?) ?? []).cast<Map<String, dynamic>>();
    final notes = (event['notes'] as String?)?.trim() ?? '';

    return Card(
        child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(_kindEmoji[kind] ?? '📌',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(event['title'] as String? ?? '',
                  style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                      color: cancelled
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: .75)
                          : null)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
              '${DateFormat('h:mm a').format(start)}${end != null ? ' – ${DateFormat(calendarDay(end) == calendarDay(start) ? 'h:mm a' : 'EEE, MMM d • h:mm a').format(end)}' : ''}',
              style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
          if (cancelled)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                  '🚫 Cancelled${statusNote.isEmpty ? '' : ' — $statusNote'}',
                  style: text.bodySmall?.copyWith(
                      color: JamJotColors.recording,
                      fontWeight: FontWeight.w600)),
            )
          else if (statusNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('🔁 $statusNote',
                  style: text.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .75))),
            ),
          if (teacherName != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('with $teacherName',
                  style: text.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .75))),
            ),
          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(notes,
                  style: text.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .75))),
            ),
          if (kids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                for (final k in kids)
                  Builder(builder: (context) {
                    final name =
                        (k['students'] as Map?)?['display_name'] as String? ??
                            '?';
                    final color =
                        studentColor(context, k['student_id'] as String);
                    final isLessonKind = !readOnly &&
                        (kind == 'lesson' || kind == 'extra_lesson');
                    final chip = Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color, width: 1.5),
                      ),
                      child: Text(isLessonKind ? '$name 🖨️' : name,
                          style: text.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface)),
                    );
                    // On lessons, a kid's chip opens their printable
                    // lesson sheet for the week.
                    return isLessonKind
                        ? InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => context.go(
                                '/lesson-sheet?student=${k['student_id']}&name=${Uri.encodeComponent(name)}'),
                            child: chip,
                          )
                        : chip;
                  }),
              ]),
            ),
          if (!readOnly &&
              (kind == 'lesson' || kind == 'extra_lesson') &&
              kids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Tap a name to open their printable lesson sheet.',
                  style: text.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .75))),
            ),
          if (!isKidView)
            Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (!isMine && !isFamily && !cancelled)
                    TextButton(
                      onPressed: () => _requestChange(context, ref),
                      child: const Text('Request a change'),
                    ),
                  if (isMine)
                    PopupMenuButton<String>(
                      tooltip: 'Change this event',
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (v) {
                        if (v == 'cancel') _cancelEvent(context, ref);
                        if (v == 'restore') _restoreEvent(context, ref);
                        if (v == 'move') _moveEvent(context, ref);
                        if (v == 'remove') _deleteEvent(context, ref);
                      },
                      itemBuilder: (context) => [
                        if (!cancelled)
                          const PopupMenuItem(
                              value: 'cancel',
                              child: Text('Cancel (keep on calendar)…')),
                        if (cancelled)
                          const PopupMenuItem(
                              value: 'restore', child: Text('Restore')),
                        const PopupMenuItem(
                            value: 'move', child: Text('Reschedule…')),
                        const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove entirely…',
                                style:
                                    TextStyle(color: JamJotColors.recording))),
                      ],
                    ),
                ]),
        ],
      ),
    ));
  }
}
