import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_service.dart';
import '../library/library_screen.dart' show showCreateLessonDialog;
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/jamjot_card.dart';
import '../../widgets/maestro_loader.dart';

/// Where a grown-up (parent now; teachers use the same rules) builds the
/// current practice list for one student.
class LessonBuilderScreen extends ConsumerStatefulWidget {
  const LessonBuilderScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.enrollmentId,
    this.sectionLabel,
  });

  final String studentId;
  final String studentName;

  /// Which connection this list belongs to (null = family-run practice).
  final String? enrollmentId;
  final String? sectionLabel;

  @override
  ConsumerState<LessonBuilderScreen> createState() =>
      _LessonBuilderScreenState();
}

class _LessonBuilderScreenState extends ConsumerState<LessonBuilderScreen> {
  bool _busy = false;

  Future<Map<String, dynamic>> _ensureLesson() async {
    final existing = await ref.read(
        lessonForEnrollmentProvider((widget.studentId, widget.enrollmentId))
            .future);
    if (existing != null) return existing;
    final uid = JamJotBackend.client.auth.currentUser!.id;
    final lesson = await JamJotBackend.client
        .from('lessons')
        .insert({
          'student_id': widget.studentId,
          'created_by': uid,
          'title': 'This week',
          if (widget.enrollmentId != null) 'enrollment_id': widget.enrollmentId,
        })
        .select()
        .single();
    ref.invalidate(currentLessonProvider(widget.studentId));
    ref.invalidate(
        lessonForEnrollmentProvider((widget.studentId, widget.enrollmentId)));
    return lesson;
  }

  Future<void> _editGoals() async {
    final lesson = await _ensureLesson();
    final days = TextEditingController(
        text: '${(lesson['goal_days'] as num?)?.toInt() ?? 4}');
    final minutes = TextEditingController(
        text: '${(lesson['goal_minutes'] as num?)?.toInt() ?? 15}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: const Text('Weekly goals'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: days,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Practice days per week'),
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 10),
            TextField(
              controller: minutes,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Minutes per day'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await JamJotBackend.client.from('lessons').update({
      'goal_days': int.tryParse(days.text.trim()) ?? 4,
      'goal_minutes': int.tryParse(minutes.text.trim()) ?? 15,
    }).eq('id', lesson['id']);
    ref.invalidate(currentLessonProvider(widget.studentId));
    ref.invalidate(
        lessonForEnrollmentProvider((widget.studentId, widget.enrollmentId)));
  }

  Future<void> _addSong() async {
    final title = TextEditingController();
    final note = TextEditingController();
    final minutes = TextEditingController();
    final book = TextEditingController();
    final pages = TextEditingController();
    // Founder-directed 2026-11-05: three options, play-only by default.
    var kind = 'play';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: const Text('Add a song'),
        content: StatefulBuilder(
            builder: (context, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Song name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Note (optional) — e.g. "slowly, count out loud"'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: book,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: 'Book (optional)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: pages,
                  decoration:
                      const InputDecoration(labelText: 'Page(s) (optional)'),
                ),
              ),
            ]),
            TextField(
              controller: minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Minutes goal for this song (optional)'),
            ),
            const SizedBox(height: 6),
            RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('🎹 Instrument play only'),
              value: 'play',
              groupValue: kind,
              onChanged: (v) => setLocal(() => kind = v ?? 'play'),
            ),
            RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('✍️ Written only'),
              value: 'written',
              groupValue: kind,
              onChanged: (v) => setLocal(() => kind = v ?? 'play'),
            ),
            RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('✍️🎹 Instrument play & written'),
              subtitle: const Text(
                  'Written parts finish after page photos are uploaded and a caregiver confirms with their PIN'),
              value: 'both',
              groupValue: kind,
              onChanged: (v) => setLocal(() => kind = v ?? 'play'),
            ),
          ],
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final lesson = await _ensureLesson();
      final count = (lesson['assignments'] as List? ?? []).length;
      await JamJotBackend.client.from('assignments').insert({
        'lesson_id': lesson['id'],
        'title': title.text.trim(),
        'song_note': note.text.trim(),
        'suggested_minutes': int.tryParse(minutes.text.trim()),
        'order_idx': count,
        if (book.text.trim().isNotEmpty) 'book': book.text.trim(),
        if (pages.text.trim().isNotEmpty) 'pages': pages.text.trim(),
        'kind': kind,
      });
      // Quick-added songs are filed into the assignment library too
      // (founder-directed 2026-11-05).
      await rememberAssignmentsInLibrary([
        {
          'title': title.text.trim(),
          'book': book.text.trim(),
          'pages': pages.text.trim(),
          'note': note.text.trim(),
          'kind': kind,
          'suggested_minutes': int.tryParse(minutes.text.trim()),
        }
      ]);
      ref.invalidate(currentLessonProvider(widget.studentId));
    ref.invalidate(
        lessonForEnrollmentProvider((widget.studentId, widget.enrollmentId)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeSong(String assignmentId) async {
    await JamJotBackend.client
        .from('assignments')
        .delete()
        .eq('id', assignmentId);
    ref.invalidate(currentLessonProvider(widget.studentId));
    ref.invalidate(
        lessonForEnrollmentProvider((widget.studentId, widget.enrollmentId)));
  }

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(
        lessonForEnrollmentProvider((widget.studentId, widget.enrollmentId)));
    final text = Theme.of(context).textTheme;
    final lesson = lessonAsync.valueOrNull;
    final assignments =
        (lesson?['assignments'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sectionLabel == null
            ? "${widget.studentName}'s practice list"
            : "${widget.studentName} — ${widget.sectionLabel}"),
        leading: BackButton(onPressed: () => context.go('/home')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'These songs show up in ${widget.studentName}\'s practice sessions. Finishing a song earns fans and berries.',
              style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
            ),
            const SizedBox(height: 16),
            JamJotCard(
              emoji: '🎯',
              tint: JamJotColors.marigoldTint,
              title: 'Weekly goals',
              subtitle: lesson == null
                  ? 'Days per week & minutes per day'
                  : '${(lesson['goal_days'] as num?)?.toInt() ?? 4} days a week • ${(lesson['goal_minutes'] as num?)?.toInt() ?? 15} minutes a day',
              trailing: const Icon(Icons.edit_outlined),
              onTap: _editGoals,
            ),
            const SizedBox(height: 16),
            if (lessonAsync.isLoading)
              const Center(child: MaestroLoader())
            else if (assignments.isEmpty)
              JamJotCard(
                emoji: '🎵',
                tint: JamJotColors.blueberryTint,
                title: 'No songs yet',
                subtitle: 'Add the first song to build this week\'s practice.',
              )
            else
              for (final a in assignments) ...[
                JamJotCard(
                  emoji: '🎼',
                  tint: JamJotColors.blueberryTint,
                  title: a['title'] as String,
                  subtitle: (a['song_note'] as String?)?.isNotEmpty == true
                      ? a['song_note'] as String
                      : null,
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeSong(a['id'] as String),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : _addSong,
              child: Text(_busy ? 'Saving…' : '+ Add a song'),
            ),
            if (assignments.isNotEmpty) ...[
              const SizedBox(height: 10),
              // Carry this lesson into next week — fully editable (remove,
              // add, create) before it saves/assigns (founder-directed
              // 2026-11-05).
              OutlinedButton.icon(
                onPressed: () => showCreateLessonDialog(
                  context,
                  ref,
                  student: {
                    'id': widget.studentId,
                    'display_name': widget.studentName,
                  },
                  enrollmentId: widget.enrollmentId,
                  draft: draftFromLesson(lesson!),
                ),
                icon: const Icon(Icons.event_repeat, size: 18),
                label: const Text('Re-assign'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
