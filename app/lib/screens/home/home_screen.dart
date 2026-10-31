import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/dancing_note.dart';
import '../../widgets/jamjot_card.dart';
import '../library/library_screen.dart' show showCreateLessonDialog;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final active = ref.watch(activeStudentProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;

    final String greetingName;
    if (active != null) {
      greetingName = active['display_name'] as String;
    } else {
      final full = (profile?['full_name'] as String?)?.trim() ?? '';
      greetingName = full.isEmpty ? 'there' : full.split(' ').first;
    }
    final isKid = active != null;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Hi, $greetingName! 👋',
                    style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              ),
              IconButton(
                tooltip: 'Switch profile',
                onPressed: () => context.go('/profiles'),
                icon: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isKid
                        ? JamJotColors.marigoldTint
                        : JamJotColors.blueberryTint,
                    shape: BoxShape.circle,
                    border: Border.all(color: JamJotColors.ink, width: 2),
                  ),
                  child: Text(isKid ? '🎵' : '🧑',
                      style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
          Text(
            isKid
                ? 'Ready to make some music?'
                : 'JamJot is under construction — screens light up as they land.',
            style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
          ),
          const SizedBox(height: 16),
          if (isKid) ...[
            const Center(child: DancingNote(size: 140)),
            const SizedBox(height: 16),
            JamJotCard(
              emoji: '🎻',
              title: (active['instruments'] as List?)?.join(' · ') ?? 'Music',
              subtitle: 'Tap to start a practice session!',
              tint: JamJotColors.blueberryTint,
              onTap: () => context.go('/practice'),
            ),
            const SizedBox(height: 12),
            Consumer(builder: (context, ref, _) {
              final balance = ref
                  .watch(berryBalanceProvider(active['id'] as String))
                  .valueOrNull;
              return JamJotCard(
                emoji: '🫐',
                title: balance == null
                    ? 'Berry jar'
                    : '$balance berr${balance == 1 ? 'y' : 'ies'} in your jar',
                subtitle: balance == null || balance == 0
                    ? 'Practice 15+ minutes to start filling it up!'
                    : 'Keep practicing to grow your stash for the Market.',
                tint: JamJotColors.plumTint,
              );
            }),
            const SizedBox(height: 12),
            Consumer(builder: (context, ref, _) {
              final fans = ref
                  .watch(fanTotalProvider(active['id'] as String))
                  .valueOrNull;
              return JamJotCard(
                emoji: '🕶️',
                title: fans == null || fans == 0
                    ? 'Your crowd'
                    : '$fans fan${fans == 1 ? '' : 's'} cheering for you',
                subtitle: fans == null || fans == 0
                    ? 'Finish songs in practice to win your first fans!'
                    : 'Every finished song brings more fans to your stage.',
                tint: JamJotColors.marigoldTint,
              );
            }),
            const SizedBox(height: 12),
            JamJotCard(
              emoji: '📼',
              title: 'My practices',
              subtitle: 'Listen back and see how far you have come.',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(
                  '/history?student=${active['id']}&name=${Uri.encodeComponent(active['display_name'] as String)}'),
            ),
          ] else ...[
            Consumer(builder: (context, ref, _) {
              final teacher = ref.watch(myTeacherProvider).valueOrNull;
              if (teacher == null) return const SizedBox.shrink();
              return Column(children: [
                JamJotCard(
                  emoji: '🎻',
                  tint: JamJotColors.blueberryTint,
                  title: 'My teaching',
                  subtitle:
                      'Invite families, see your students, assign lessons.',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/teaching'),
                ),
                const SizedBox(height: 12),
              ]);
            }),
            JamJotCard(
              emoji: '📚',
              tint: JamJotColors.plumTint,
              title: 'My Library',
              subtitle:
                  'Your music files, saved assignments, and lesson templates.',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/library'),
            ),
            const SizedBox(height: 12),
            Consumer(builder: (context, ref, _) {
              final students =
                  ref.watch(myStudentsProvider).valueOrNull ?? [];
              return Column(
                children: [
                  for (final kid in students) ...[
                    JamJotCard(
                      emoji: '🎼',
                      tint: JamJotColors.blueberryTint,
                      title: "${kid['display_name']}'s practice list",
                      subtitle:
                          'Add this week\'s songs — they earn fans & berries for finishing them.',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(
                          '/lesson-builder?student=${kid['id']}&name=${Uri.encodeComponent(kid['display_name'] as String)}'),
                    ),
                    const SizedBox(height: 12),
                    JamJotCard(
                      emoji: '🪄',
                      tint: JamJotColors.marigoldTint,
                      title: "Assign ${kid['display_name']} a lesson",
                      subtitle:
                          'Build from your library and set goals & the start date.',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          showCreateLessonDialog(context, ref, student: kid),
                    ),
                    const SizedBox(height: 12),
                    JamJotCard(
                      emoji: '📼',
                      title: "${kid['display_name']}'s practice history",
                      subtitle:
                          'Sessions, song ratings, and the recordings to listen back.',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(
                          '/history?student=${kid['id']}&name=${Uri.encodeComponent(kid['display_name'] as String)}'),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }),
            const JamJotCard(
              emoji: '🏗️',
              title: 'Coming next',
              subtitle:
                  'Sheet music on screen during practice → song recognition → messages & calendar.',
              tint: JamJotColors.marigoldTint,
            ),
          ],
        ],
      ),
    );
  }
}
