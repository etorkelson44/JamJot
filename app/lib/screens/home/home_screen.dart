import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/coin_pouch.dart';
import '../profile/my_profile_screen.dart' show PermissionChangeNotices;
import '../../widgets/jamjot_card.dart';
import '../../widgets/instrument_icon.dart';
import '../../widgets/notestar_art.dart';

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

    final page = SafeArea(
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
              // The corner chips (Jam Jar + profile, from the shell) float
              // here — reserve their width so the greeting clears them.
              SizedBox(width: isKid ? 122 : 48),
            ],
          ),
          Text(
            isKid
                ? 'Ready to shine?'
                : 'Here is what is happening in your studio and at home.',
            style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
          ),
          const SizedBox(height: 16),
          if (isKid) ...[
            // NoteStar (2026-11-15): the star-note greets kids (Home isn't
            // about one instrument), with the fan count underneath.
            SizedBox(
              height: 210,
              child: Stack(alignment: Alignment.center, children: const [
                Positioned(left: 8, top: 10, child: PaperAccent('star_big_lime', size: 44)),
                Positioned(right: 14, top: 0, child: PaperAccent('moon_blue', size: 46)),
                Positioned(right: 0, bottom: 34, child: PaperAccent('star_small_violet', size: 34)),
                Positioned(left: 20, bottom: 26, child: PaperAccent('dot_pink', size: 22)),
                StarBounce(size: 170),
              ]),
            ),
            const SizedBox(height: 8),
            Center(child: FanCount(studentId: active['id'] as String, big: true)),
            const SizedBox(height: 4),
            Center(
              child: Text('Finish songs and practices to grow your fans!',
                  style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
            ),
            const SizedBox(height: 16),
            JamJotCard(
              leading: instrumentIcon(
                  instrumentsOf(active).firstOrNull,
                  size: 34),
              title: instrumentsOf(active).isEmpty
                  ? 'Music'
                  : instrumentsOf(active).join(' · '),
              titleWidget: instrumentsOf(active).length > 1
                  ? InstrumentList(instrumentsOf(active),
                      iconSize: 22,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700))
                  : null,
              subtitle: "Let's practice!",
              tint: JamJotColors.blueberryTint,
              onTap: () => context.go('/practice'),
            ),
            const SizedBox(height: 12),
            Consumer(builder: (context, ref, _) {
              final balance = ref
                  .watch(berryBalanceProvider(active['id'] as String))
                  .valueOrNull;
              return JamJotCard(
                leading: const JamCoin(size: 28),
                title: balance == null
                    ? 'Coins'
                    : '$balance coin${balance == 1 ? '' : 's'}',
                subtitle: balance == null || balance == 0
                    ? 'Finish a song or meet your daily goal to earn coins.'
                    : 'Spend them on rewards from home or your teacher.',
                tint: JamJotColors.marigoldTint,
                onTap: () => context.go('/market'),
              );
            }),
            const SizedBox(height: 12),
            JamJotCard(
              leading: const PaperAccent('star_big_blue', size: 34),
              title: 'Recordings & albums',
              subtitle: 'Hear how far you have come this week.',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/recordings'),
            ),
            const SizedBox(height: 12),
            Consumer(builder: (context, ref, _) {
              final chats = ref.watch(myChatsProvider).valueOrNull ?? [];
              if (chats.isEmpty) return const SizedBox.shrink();
              return JamJotCard(
                emoji: '💬',
                tint: JamJotColors.blueberryTint,
                title: 'Messages',
                subtitle: 'Chat with your teacher (grown-ups can see it).',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/messages'),
              );
            }),
          ] else ...[
            const PermissionChangeNotices(),
            Consumer(builder: (context, ref, _) {
              final teacher = ref.watch(myTeacherProvider).valueOrNull;
              if (teacher == null) return const SizedBox.shrink();
              return Column(children: [
                JamJotCard(
                  leading: instrumentIcon(
                      (teacher['instruments'] as List?)?.firstOrNull
                          as String?,
                      size: 34),
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
            Consumer(builder: (context, ref, _) {
              final chats = ref.watch(myChatsProvider).valueOrNull ?? [];
              if (chats.isEmpty) return const SizedBox.shrink();
              return Column(children: [
                JamJotCard(
                  emoji: '💬',
                  tint: JamJotColors.blueberryTint,
                  title: 'Messages',
                  subtitle: 'One chat per student–teacher connection.',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/messages'),
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
              final students = ref.watch(myStudentsProvider).valueOrNull ?? [];
              return Column(
                children: [
                  for (final kid in students) ...[
                    JamJotCard(
                      emoji: (kid['display_name'] as String).isEmpty
                          ? '?'
                          : (kid['display_name'] as String)[0].toUpperCase(),
                      tint: JamJotColors.neutral,
                      title: kid['display_name'] as String,
                      extra: InstrumentList(
                          instrumentsOf(kid),
                          iconSize: 20,
                          style: Theme.of(context).textTheme.bodySmall),
                      subtitle: 'Practice list, lessons, history & chat',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/kid?student=${kid['id']}'),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }),
            JamJotCard(
              emoji: '⚙️',
              title: 'Account settings',
              subtitle:
                  'Your name, phone, password, and your role for each kid.',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/account'),
            ),
          ],
        ],
      ),
    );
    // NoteStar: plain white ground (no venue backdrop, no Maestro tab).
    return page;
  }
}
