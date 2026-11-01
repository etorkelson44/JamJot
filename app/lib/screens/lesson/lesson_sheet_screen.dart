import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/print_page.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';

/// Every lesson the student is currently practicing — the newest arrived
/// lesson from each connection (every teacher plus family-run), kept
/// separate so the sheet can show who assigned what.
final sheetLessonsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, studentId) async {
  final rows = await JamJotBackend.client
      .from('lessons')
      .select('*, assignments(*)')
      .eq('student_id', studentId)
      .order('created_at', ascending: false)
      .limit(25);
  final today = DateTime.now();
  final newestPerConnection = <String, Map<String, dynamic>>{};
  for (final r in rows) {
    final ws = r['week_start'] as String?;
    if (ws != null && DateTime.parse(ws).isAfter(today)) continue;
    final key = (r['enrollment_id'] as String?) ?? 'family';
    newestPerConnection.putIfAbsent(key, () => Map<String, dynamic>.from(r));
  }
  final enrollments =
      await ref.watch(kidEnrollmentsProvider(studentId).future);
  final labels = {
    for (final e in enrollments)
      e['id'] as String:
          (e['teachers'] as Map?)?['display_name'] as String? ?? 'Teacher',
  };
  final out = <Map<String, dynamic>>[];
  for (final entry in newestPerConnection.entries) {
    final l = entry.value;
    final assignments = (l['assignments'] as List? ?? [])
        .cast<Map<String, dynamic>>()
      ..sort((a, b) => (a['order_idx'] as int? ?? 0)
          .compareTo(b['order_idx'] as int? ?? 0));
    l['assignments'] = assignments;
    l['source'] = entry.key == 'family' ? 'Family' : labels[entry.key];
    out.add(l);
  }
  return out;
});

/// A clean, paper-friendly view of a student's current lesson(s): goals,
/// notes, every song with its note and a row of day-boxes to tick with a
/// pencil. The Print button opens the browser's print dialog, where
/// "Save as PDF" also lives.
class LessonSheetScreen extends ConsumerWidget {
  const LessonSheetScreen(
      {super.key, required this.studentId, required this.studentName});
  final String studentId;
  final String studentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(sheetLessonsProvider(studentId));
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("$studentName's lesson sheet"),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          if (printingSupported)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: printPage,
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Print / Save as PDF'),
              ),
            ),
        ],
      ),
      body: lessons.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Could not load the lesson sheet.')),
        data: (items) => items.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No current lesson to print yet.'),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text('🎵 JamJot practice sheet',
                          style: text.labelLarge
                              ?.copyWith(color: JamJotColors.inkSoft)),
                      const SizedBox(height: 4),
                      Text(studentName,
                          style: text.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                          'Printed ${DateFormat('EEEE, MMM d, yyyy').format(DateTime.now())}',
                          style: text.bodySmall
                              ?.copyWith(color: JamJotColors.inkSoft)),
                      const SizedBox(height: 16),
                      for (final l in items) _LessonBlock(lesson: l),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _LessonBlock extends StatelessWidget {
  const _LessonBlock({required this.lesson});
  final Map<String, dynamic> lesson;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final assignments =
        (lesson['assignments'] as List? ?? []).cast<Map<String, dynamic>>();
    final ws = lesson['week_start'] as String?;
    final note = (lesson['lesson_note'] as String?)?.trim() ?? '';
    const days = ['M', 'T', 'W', 'Th', 'F', 'Sa', 'Su'];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: JamJotColors.ink, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(lesson['title'] as String? ?? 'Lesson',
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(lesson['source'] as String? ?? '',
                      style: text.bodySmall
                          ?.copyWith(color: JamJotColors.inkSoft)),
                  if (ws != null)
                    Text(
                        'Week of ${DateFormat('MMM d').format(DateTime.parse(ws))}',
                        style: text.bodySmall
                            ?.copyWith(color: JamJotColors.inkSoft)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              'Goal: practice ${lesson['goal_days'] ?? 4} days this week, '
              '${lesson['goal_minutes'] ?? 15} minutes a day',
              style: text.bodyMedium),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Notes: $note', style: text.bodyMedium),
          ],
          const Divider(height: 20),
          for (var i = 0; i < assignments.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}. ${assignments[i]['title'] ?? 'Song'}',
                          style: text.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (((assignments[i]['song_note'] as String?) ?? '')
                          .trim()
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 18),
                          child: Text(
                              (assignments[i]['song_note'] as String).trim(),
                              style: text.bodyMedium?.copyWith(
                                  color: JamJotColors.inkSoft)),
                        ),
                    ],
                  ),
                ),
                // Day boxes to tick with a pencil.
                Row(children: [
                  for (final d in days)
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Column(children: [
                        Text(d, style: text.labelSmall),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: JamJotColors.ink, width: 1.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ]),
                    ),
                ]),
              ],
            ),
            if (i < assignments.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
