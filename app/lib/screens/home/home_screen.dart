import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../state/wardrobe.dart';
import '../../widgets/dressed_avatar.dart';
import '../../widgets/coin_pouch.dart';
import '../../widgets/fan_stage.dart';
import '../profile/my_profile_screen.dart' show PermissionChangeNotices;
import '../../widgets/jamjot_card.dart';
import '../../widgets/ask_maestro.dart';
import '../../widgets/instrument_icon.dart';

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
                ? 'Ready to make some music?'
                : 'JamJot is under construction — screens light up as they land.',
            style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
          ),
          const SizedBox(height: 16),
          if (isKid) ...[
            Center(child: _HomeAvatar(student: active)),
            const SizedBox(height: 16),
            // Which stage they're playing (the venue itself is the page
            // background behind everything).
            FanIndicator(studentId: active['id'] as String),
            const SizedBox(height: 16),
            JamJotCard(
              leading: instrumentIcon(
                  (active['instruments'] as List?)?.firstOrNull as String?,
                  size: 26,
                  fallback: '🎻'),
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
                leading: const JamCoin(size: 28),
                title: balance == null
                    ? 'Jam Jar'
                    : '$balance coin${balance == 1 ? '' : 's'} in your Jam Jar',
                subtitle: balance == null || balance == 0
                    ? 'Finish songs in practice to earn your first coins!'
                    : "Spend them at the Farmers' Market!",
                tint: JamJotColors.plumTint,
                onTap: () => context.go('/market'),
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
            Consumer(builder: (context, ref, _) {
              final chats = ref.watch(myChatsProvider).valueOrNull ?? [];
              if (chats.isEmpty) return const SizedBox.shrink();
              return Column(children: [
                JamJotCard(
                  emoji: '💬',
                  tint: JamJotColors.blueberryTint,
                  title: 'Messages',
                  subtitle: 'Chat with your teacher (grown-ups can see it).',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/messages'),
                ),
                const SizedBox(height: 12),
              ]);
            }),
            JamJotCard(
              emoji: '📼',
              title: 'My practices',
              subtitle: 'Listen back and see how far you have come.',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(
                  '/history?student=${active['id']}&name=${Uri.encodeComponent(active['display_name'] as String)}'),
            ),
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
                      size: 26,
                      fallback: '🎻'),
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
                      subtitle:
                          '${(kid['instruments'] as List?)?.join(' · ') ?? 'Music'} — practice list, lessons, history & chat',
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
            const SizedBox(height: 12),
            const JamJotCard(
              emoji: '🏗️',
              title: 'Coming next',
              subtitle:
                  'Calendar & scheduled lessons → the berry Market → song recognition.',
              tint: JamJotColors.marigoldTint,
            ),
          ],
        ],
      ),
    );
    final body = isKid
        ? VenueBackdrop(studentId: active['id'] as String, child: page)
        : page;
    // Maestro Marmalade is always one tap away on the main page.
    return Stack(children: [body, const AskMaestroTab()]);
  }
}


/// The kid's own dressed avatar greets them on their landing page,
/// bobbing gently (Maestro still lives in the Ask tab).
class _HomeAvatar extends ConsumerStatefulWidget {
  const _HomeAvatar({required this.student});
  final Map<String, dynamic> student;
  @override
  ConsumerState<_HomeAvatar> createState() => _HomeAvatarState();
}

class _HomeAvatarState extends ConsumerState<_HomeAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sid = widget.student['id'] as String;
    final avatarKey = (widget.student['avatar_key'] as String?) ?? 'jalapeno';
    final outfit = ref.watch(wardrobeProvider(sid)).outfitFor(avatarKey);
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, math.sin(_bob.value * 2 * math.pi) * 4),
        child: Transform.rotate(
            angle: math.sin(_bob.value * 2 * math.pi + 0.8) * 0.03,
            child: child),
      ),
      child: DressedAvatar(avatarKey: avatarKey, outfit: outfit, size: 140),
    );
  }
}
