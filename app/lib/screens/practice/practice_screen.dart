import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/instrument_icon.dart';
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

    // The kid's practice home, keyed so switching kids (or instrument tabs)
    // resets it fully. Kids with several instruments get a tab per
    // instrument (JJ-043-C); each tab has its own lessons, goals and progress.
    final instruments = instrumentsOf(active);
    final chosen =
        practiceInstrumentFor(active, ref.watch(activeInstrumentProvider));
    final session = PracticeSessionScreen(
        key: ValueKey('${active['id']}/${chosen ?? ''}'));
    if (instruments.length < 2) return session;
    final live = ref.watch(practiceLiveProvider);
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final i in instruments)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: ValueKey('instrument-tab-$i'),
                        selected: i == chosen,
                        onSelected: live
                            ? null
                            : (_) => ref
                                .read(activeInstrumentProvider.notifier)
                                .state = i,
                        avatar: instrumentIcon(i, size: 22),
                        label: Text(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (live)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Stop recording to switch instruments.',
                style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
          ),
        Expanded(child: session),
      ],
    );
  }
}
