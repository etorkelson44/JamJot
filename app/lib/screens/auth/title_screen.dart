import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/jamjot_theme.dart';
import '../../widgets/dancing_note.dart';

class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            children: [
              const Spacer(),
              // Erika's mascot, with a little welcome dance.
              const DancingNote(size: 230),
              const SizedBox(height: 20),
              Text('JamJot',
                  style: text.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700, letterSpacing: -2)),
              const SizedBox(height: 6),
              Text('Every minute of music goes in the jar',
                  style: text.titleMedium
                      ?.copyWith(color: JamJotColors.inkSoft)),
              const SizedBox(height: 14),
              Transform.rotate(
                angle: JamJotShape.stickerTilt,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: JamJotColors.marigoldTint,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: JamJotColors.ink, width: 1.5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.mic_none, size: 15),
                    const SizedBox(width: 6),
                    Text('Real practice, really heard',
                        style: text.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/signin?create=1'),
                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                            color: JamJotColors.marigold,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow,
                            color: JamJotColors.ink, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text("Let's play"),
                    ]),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => context.go('/signin'),
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
