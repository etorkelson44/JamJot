import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/jamjot_card.dart';

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
            JamJotCard(
              emoji: '🎻',
              title: (active['instruments'] as List?)?.join(' · ') ?? 'Music',
              subtitle: 'Your practice sessions will start here very soon.',
              tint: JamJotColors.blueberryTint,
            ),
            const SizedBox(height: 12),
            const JamJotCard(
              emoji: '🫐',
              title: 'Berry jar',
              subtitle: 'Earn berries for real practice — the jar is coming!',
              tint: JamJotColors.plumTint,
            ),
          ] else ...[
            const JamJotCard(
              emoji: '🫐',
              title: 'The backend is live',
              subtitle:
                  '27 tables, every permission rule, the berry economy — all wired to this very app.',
            ),
            const SizedBox(height: 12),
            const JamJotCard(
              emoji: '🏗️',
              title: 'Coming next',
              subtitle:
                  'The practice timer with recording → berries in the jar → lessons & messages.',
              tint: JamJotColors.blueberryTint,
            ),
            const SizedBox(height: 12),
            const JamJotCard(
              emoji: '🎨',
              title: 'Art slots ready',
              subtitle:
                  'Every drawing in the app is a placeholder file — swap in your own art anytime (see ART_MANIFEST.md).',
              tint: JamJotColors.marigoldTint,
            ),
          ],
        ],
      ),
    );
  }
}
