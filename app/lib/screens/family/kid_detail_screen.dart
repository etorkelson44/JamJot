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
            const SizedBox(height: 16),
            JamJotCard(
              emoji: '📼',
              title: 'Practice history',
              subtitle: 'All sessions, every teacher — ratings & recordings.',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(
                  '/history?student=$studentId&name=${Uri.encodeComponent(name)}'),
            ),
            const SizedBox(height: 20),
            // One section per teacher connection, each kept separate.
            Consumer(builder: (context, ref, _) {
              final enrollments = ref
                      .watch(kidEnrollmentsProvider(studentId))
                      .valueOrNull ??
                  [];
              final chats = ref.watch(myChatsProvider).valueOrNull ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in enrollments) ...[
                    _sectionHeader(
                      context,
                      '🎻 ${(e['teachers'] as Map?)?['display_name'] ?? 'Teacher'} • ${e['instrument']}',
                    ),
                    _sectionCards(
                      context,
                      ref,
                      kid: kid,
                      name: name,
                      enrollmentId: e['id'] as String,
                      sectionLabel:
                          '${(e['teachers'] as Map?)?['display_name'] ?? 'Teacher'} (${e['instrument']})',
                      chat: chats
                          .where((c) =>
                              c['enrollment_id'] == e['id'])
                          .firstOrNull,
                    ),
                    const SizedBox(height: 20),
                  ],
                  _sectionHeader(context, '🏡 Family-run practice'),
                  _sectionCards(
                    context,
                    ref,
                    kid: kid,
                    name: name,
                    enrollmentId: null,
                    sectionLabel: 'Family-run',
                    chat: null,
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      );

  Widget _sectionCards(
    BuildContext context,
    WidgetRef ref, {
    required Map<String, dynamic> kid,
    required String name,
    required String? enrollmentId,
    required String sectionLabel,
    required Map<String, dynamic>? chat,
  }) {
    final enrollParam = enrollmentId == null
        ? ''
        : '&enrollment=$enrollmentId&section=${Uri.encodeComponent(sectionLabel)}';
    return Column(children: [
      JamJotCard(
        emoji: '🎼',
        tint: JamJotColors.blueberryTint,
        title: 'Practice list',
        subtitle: 'Songs, notes, and goals for $sectionLabel.',
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(
            '/lesson-builder?student=$studentId&name=${Uri.encodeComponent(name)}$enrollParam'),
      ),
      const SizedBox(height: 10),
      JamJotCard(
        emoji: '🪄',
        tint: JamJotColors.marigoldTint,
        title: 'Assign a lesson',
        subtitle: 'From your library, with goals & a start date.',
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showCreateLessonDialog(context, ref,
            student: kid, enrollmentId: enrollmentId),
      ),
      if (chat != null) ...[
        const SizedBox(height: 10),
        JamJotCard(
          emoji: '💬',
          title: 'Chat with ${chat['teacher_name']}',
          subtitle: chat['instrument'] as String?,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(
              '/chat?enrollment=${chat['enrollment_id']}&title=${Uri.encodeComponent('$name × ${chat['teacher_name']}')}&primary=${chat['i_am_primary'] == true ? 1 : 0}&teacher=${chat['teacher_profile_id']}'),
        ),
      ],
      if (enrollmentId != null) ...[
        const SizedBox(height: 10),
        JamJotCard(
          emoji: '🧺',
          tint: JamJotColors.plumTint,
          title: 'Teacher\'s market stand',
          subtitle: 'Rewards this teacher stocks — opens with the Market.',
        ),
      ],
    ]);
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
