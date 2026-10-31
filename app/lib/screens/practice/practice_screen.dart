import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/dancing_note.dart';

class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeStudentProvider);
    final text = Theme.of(context).textTheme;

    if (active == null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎵', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text('Practice is for the musicians!',
                    textAlign: TextAlign.center,
                    style: text.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Switch to a kid profile and the practice stage opens up.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium
                      ?.copyWith(color: JamJotColors.inkSoft),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => context.go('/profiles'),
                  child: const Text('Switch profile'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                const DancingNote(size: 150),
                const SizedBox(height: 12),
                Text('Ready, ${active['display_name']}?',
                    style: text.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: JamJotColors.marigoldTint,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: JamJotColors.ink, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mic, color: JamJotColors.recording),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Starting turns on listening & recording until you tap "I\'m done".',
                          style: text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Practice 15 minutes or more to fill your session goal and earn berries!',
                  textAlign: TextAlign.center,
                  style:
                      text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go('/practice-session'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.play_arrow),
                      SizedBox(width: 8),
                      Text('Start practicing'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
