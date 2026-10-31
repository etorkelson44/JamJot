import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';

/// Everything on the family's calendar that this person may see.
final calendarEventsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final from = DateTime.now().subtract(const Duration(days: 14));
  final rows = await JamJotBackend.client
      .from('calendar_events')
      .select(
          '*, event_students(student_id, students(display_name)), teachers(display_name)')
      .gte('starts_at', from.toUtc().toIso8601String())
      .order('starts_at', ascending: true)
      .limit(200);
  return rows.cast<Map<String, dynamic>>();
});

const _kindEmoji = {
  'lesson': '🎒',
  'extra_lesson': '🎒',
  'performance': '🎭',
  'event': '🎪',
  'family': '🏡',
};

/// Each kid gets a steady color for their calendar chip.
Color studentColor(String id) {
  const palette = [
    JamJotColors.blueberry,
    JamJotColors.plum,
    JamJotColors.marigold,
    JamJotColors.leaf,
    JamJotColors.blueberryDark,
    JamJotColors.plumDark,
  ];
  return palette[id.hashCode.abs() % palette.length];
}

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(calendarEventsProvider).valueOrNull ?? [];
    final activeKid = ref.watch(activeStudentProvider);
    final teacher = ref.watch(myTeacherProvider).valueOrNull;
    final students = ref.watch(myStudentsProvider).valueOrNull ?? [];
    final uid = JamJotBackend.client.auth.currentUser?.id;
    final text = Theme.of(context).textTheme;

    // Kids see only their own events.
    final shown = activeKid == null
        ? events
        : events
            .where((e) => ((e['event_students'] as List?) ?? [])
                .any((es) => es['student_id'] == activeKid['id']))
            .toList();

    // Group by day.
    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final e in shown) {
      final d = DateTime.parse(e['starts_at'] as String).toLocal();
      final key = DateFormat('yyyy-MM-dd').format(d);
      (byDay[key] ??= []).add(e);
    }
    final dayKeys = byDay.keys.toList()..sort();
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('Calendar',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (activeKid == null) ...[
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (teacher != null)
                FilledButton.icon(
                  onPressed: () =>
                      _scheduleDialog(context, ref, teacher: teacher),
                  icon: const Icon(Icons.add),
                  label: const Text('Schedule lesson / event'),
                ),
              if (students.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _familyEventDialog(context, ref, students),
                  icon: const Icon(Icons.add),
                  label: const Text('Add family event'),
                ),
            ]),
            const SizedBox(height: 6),
            Text(
              'Family events stay private to your family — teachers and studios never see them.',
              style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
            ),
            const SizedBox(height: 10),
          ],
          if (dayKeys.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                activeKid == null
                    ? 'Nothing scheduled yet. Lessons from teachers and your family events will all land here.'
                    : 'Nothing on your calendar yet — your lessons and performances will show up here! 🎵',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
              ),
            )
          else
            for (final key in dayKeys) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Text(
                  key == todayKey
                      ? 'Today'
                      : DateFormat('EEEE, MMM d')
                          .format(DateTime.parse(key)),
                  style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: key == todayKey
                          ? JamJotColors.blueberry
                          : JamJotColors.ink),
                ),
              ),
              for (final e in byDay[key]!) ...[
                _EventCard(
                  event: e,
                  isMine: e['owner_id'] == uid,
                  isKidView: activeKid != null,
                ),
                const SizedBox(height: 8),
              ],
            ],
        ],
      ),
    );
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
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
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
                          labelText: 'Repeat weekly for how many weeks? (1 = just once)'),
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
              onPressed: picked.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(true),
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
      final count =
          (int.tryParse(weeks.text.trim()) ?? 1).clamp(1, 26);
      for (var i = 0; i < (kind == 'lesson' ? count : 1); i++) {
        final startsAt = DateTime(date.year, date.month, date.day,
                time.hour, time.minute)
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

class _EventCard extends ConsumerWidget {
  const _EventCard(
      {required this.event, required this.isMine, required this.isKidView});

  final Map<String, dynamic> event;
  final bool isMine;
  final bool isKidView;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final kind = event['kind'] as String? ?? 'event';
    final isFamily = kind == 'family';
    final start = DateTime.parse(event['starts_at'] as String).toLocal();
    final end = event['ends_at'] == null
        ? null
        : DateTime.parse(event['ends_at'] as String).toLocal();
    final teacherName =
        (event['teachers'] as Map?)?['display_name'] as String?;
    final kids = ((event['event_students'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    final notes = (event['notes'] as String?)?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isFamily
            ? Border.all(color: JamJotColors.outline, width: 2)
            : Border.all(color: JamJotColors.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(_kindEmoji[kind] ?? '📌',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(event['title'] as String? ?? '',
                  style:
                      text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Text(
              '${DateFormat('h:mm a').format(start)}${end != null ? '–${DateFormat('h:mm a').format(end)}' : ''}',
              style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ]),
          if (teacherName != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('with $teacherName',
                  style:
                      text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
            ),
          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(notes,
                  style:
                      text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
            ),
          if (kids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                for (final k in kids)
                  Builder(builder: (context) {
                    final name = (k['students'] as Map?)?['display_name']
                            as String? ??
                        '?';
                    final color = studentColor(k['student_id'] as String);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color, width: 1.5),
                      ),
                      child: Text(name,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: JamJotColors.ink)),
                    );
                  }),
              ]),
            ),
          if (!isKidView)
            Row(children: [
              if (!isMine && !isFamily)
                TextButton(
                  onPressed: () => _requestChange(context, ref),
                  child: const Text('Request a change'),
                ),
              const Spacer(),
              if (isMine)
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _deleteEvent(context, ref),
                ),
            ]),
        ],
      ),
    );
  }
}
