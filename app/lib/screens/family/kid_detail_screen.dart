import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/jamjot_card.dart';
import '../library/library_screen.dart' show showCreateLessonDialog;

/// One kid's page in the grown-up view: everything about this musician
/// in one place, nothing mixed with their siblings.
class KidDetailScreen extends ConsumerWidget {
  const KidDetailScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(myStudentsProvider).valueOrNull ?? [];
    final kid = students.where((s) => s['id'] == studentId).firstOrNull;
    final text = Theme.of(context).textTheme;

    if (kid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final name = kid['display_name'] as String;
    final chats = ref.watch(myChatsProvider).valueOrNull ?? [];
    final kidChat =
        chats.where((c) => c['student_name'] == name).firstOrNull;
    final berries =
        ref.watch(berryBalanceProvider(studentId)).valueOrNull;
    final fans = ref.watch(fanTotalProvider(studentId)).valueOrNull;
    final progress =
        ref.watch(weeklyProgressProvider(studentId)).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        leading: BackButton(onPressed: () => context.go('/home')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: JamJotColors.marigoldTint,
                    shape: BoxShape.circle,
                    border: Border.all(color: JamJotColors.ink, width: 2),
                  ),
                  child: const Text('🎵', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: text.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        (kid['instruments'] as List?)?.join(' · ') ?? '',
                        style: text.bodyMedium
                            ?.copyWith(color: JamJotColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statChip('🫐 ${berries ?? '…'} berries'),
                _statChip('🕶️ ${fans ?? '…'} fans'),
                if (progress != null)
                  _statChip(
                      '📅 ${progress['days']} day${progress['days'] == 1 ? '' : 's'} this week'),
                if (progress != null)
                  _statChip('⏱️ ${progress['today_minutes']} min today'),
              ],
            ),
            const SizedBox(height: 20),
            JamJotCard(
              emoji: '🎼',
              tint: JamJotColors.blueberryTint,
              title: 'Practice list',
              subtitle: 'This week\'s songs, notes, and goals.',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(
                  '/lesson-builder?student=$studentId&name=${Uri.encodeComponent(name)}'),
            ),
            const SizedBox(height: 12),
            JamJotCard(
              emoji: '🪄',
              tint: JamJotColors.marigoldTint,
              title: 'Assign a lesson',
              subtitle: 'Build from your library, set goals & the start date.',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showCreateLessonDialog(context, ref, student: kid),
            ),
            const SizedBox(height: 12),
            JamJotCard(
              emoji: '📼',
              title: 'Practice history',
              subtitle: 'Sessions, song ratings, and recordings.',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(
                  '/history?student=$studentId&name=${Uri.encodeComponent(name)}'),
            ),
            if (kidChat != null) ...[
              const SizedBox(height: 12),
              JamJotCard(
                emoji: '💬',
                tint: JamJotColors.blueberryTint,
                title: 'Chat with ${kidChat['teacher_name']}',
                subtitle: kidChat['instrument'] as String?,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(
                    '/chat?enrollment=${kidChat['enrollment_id']}&title=${Uri.encodeComponent('$name × ${kidChat['teacher_name']}')}&primary=${kidChat['i_am_primary'] == true ? 1 : 0}&teacher=${kidChat['teacher_profile_id']}'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: JamJotColors.ink, width: 1.5),
        ),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );
}
