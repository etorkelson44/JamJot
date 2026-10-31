import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import 'practice_session_screen.dart';

/// The Practice tab. For kids it IS the practice home: lessons, goals,
/// and the day's songs — recording starts inside each song.
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

    // The kid's practice home, keyed so switching kids resets it fully.
    return PracticeSessionScreen(key: ValueKey(active['id']));
  }
}
