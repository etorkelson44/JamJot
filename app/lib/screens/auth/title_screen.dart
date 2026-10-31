import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/jamjot_theme.dart';
import '../../widgets/dancing_note.dart';
import '../../widgets/jamjot_card.dart';

void _showHowAccountsWork(BuildContext context) {
  final text = Theme.of(context).textTheme;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: JamJotColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      side: JamJotShape.border,
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('How JamJot accounts work',
                style:
                    text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const _ExplainRow(
              emoji: '🧑‍🧒',
              tint: JamJotColors.blueberryTint,
              title: 'Families',
              body:
                  'One grown-up account runs the whole family. Kids do not need their own accounts — they get profiles inside yours, each protected by a PIN. Grandparents and other caregivers join by invite. Works great with a teacher or on your own.',
            ),
            const SizedBox(height: 12),
            const _ExplainRow(
              emoji: '🎻',
              tint: JamJotColors.marigoldTint,
              title: 'Teachers',
              body:
                  'One account whether you teach independently or as part of a studio. You connect with your students by sending families a simple invite link.',
            ),
            const SizedBox(height: 12),
            const _ExplainRow(
              emoji: '🏫',
              tint: JamJotColors.plumTint,
              title: 'Studios',
              body:
                  'The studio owner creates the studio, then teachers join it with an invite. Families connect using the studio code and pick their teacher.',
            ),
            const SizedBox(height: 16),
            Text(
              'Whichever you are, start with "Let\'s play" — the app asks one simple question after sign-up and takes it from there.',
              style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ExplainRow extends StatelessWidget {
  const _ExplainRow({
    required this.emoji,
    required this.tint,
    required this.title,
    required this.body,
  });

  final String emoji;
  final Color tint;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: JamJotColors.ink, width: 2),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style:
                      text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(body,
                  style:
                      text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
            ],
          ),
        ),
      ],
    );
  }
}

class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sign in, tucked at the top for returning families & teachers.
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => context.go('/signin'),
                  child: const Text('Sign in',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              // Erika's mascot, with a little welcome dance.
              const DancingNote(size: 170),
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
              const SizedBox(height: 28),
              JamJotCard(
                emoji: '🧑‍🧒',
                tint: JamJotColors.blueberryTint,
                title: 'I am a family grown-up',
                subtitle:
                    'Set up kid profiles inside one account — connect a teacher or studio anytime.',
                onTap: () => context.go('/signin?create=1&role=family'),
              ),
              const SizedBox(height: 12),
              JamJotCard(
                emoji: '🎻',
                tint: JamJotColors.marigoldTint,
                title: 'I teach music',
                subtitle:
                    'On my own, running a studio, or joining one — all start here.',
                onTap: () => context.go('/signin?create=1&role=teacher'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => _showHowAccountsWork(context),
                child: const Text('How do accounts work?'),
              ),
            ],
          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
