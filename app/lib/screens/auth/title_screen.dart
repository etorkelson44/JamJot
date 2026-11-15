import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/jamjot_theme.dart';
import '../../widgets/ask_maestro.dart' show TisdaleImprint;

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
            Text('How NoteStar accounts work',
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
              'Whichever you are, pick the button that fits you — the app asks one simple question after sign-up and takes it from there.',
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
    // NoteStar welcome (2026-11-15), built to the NoteStar canvas: lime
    // ground, Erika's logo with no frame, ink pills.
    return Scaffold(
      backgroundColor: JamJotColors.marigold,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Stack(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                          child: Column(
                            children: [
                              const SizedBox(height: 56),
                              const Spacer(),
                              Image.asset('assets/art/notestar_logo.png',
                                  width: 240,
                                  height: 240,
                                  fit: BoxFit.contain,
                                  semanticLabel:
                                      'NoteStar logo: a music note with a star',
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox(width: 240, height: 240)),
                              const SizedBox(height: 4),
                              const Text('NoteStar',
                                  style: TextStyle(
                                      fontFamily: JamJotType.display,
                                      fontSize: 54,
                                      height: 1,
                                      letterSpacing: 1,
                                      color: JamJotColors.ink)),
                              const SizedBox(height: 12),
                              const Text('Practice. Progress. Shine.',
                                  style: TextStyle(
                                      fontFamily: JamJotType.title,
                                      fontSize: 19,
                                      color: JamJotColors.ink)),
                              const Spacer(),
                              const SizedBox(height: 28),
                              _InkPill(
                                label: "I'm a family grown-up",
                                onTap: () =>
                                    context.go('/signin?create=1&role=family'),
                              ),
                              const SizedBox(height: 14),
                              _InkPill(
                                label: 'I teach music',
                                light: true,
                                onTap: () =>
                                    context.go('/signin?create=1&role=teacher'),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                style: TextButton.styleFrom(
                                    foregroundColor: JamJotColors.ink,
                                    minimumSize: const Size(48, 48)),
                                onPressed: () => _showHowAccountsWork(context),
                                child: const Text('How do accounts work?',
                                    style: TextStyle(
                                        fontFamily: JamJotType.title,
                                        fontSize: 15,
                                        decoration: TextDecoration.underline)),
                              ),
                              const SizedBox(height: 4),
                              const Center(
                                  child: TisdaleImprint(
                                      height: 32, opacity: 0.22)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 16,
                      child: _InkPill(
                        label: 'Sign in',
                        compact: true,
                        onTap: () => context.go('/signin'),
                      ),
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

/// Rounded pill button with a 3px ink outline and a hard ink shadow.
class _InkPill extends StatelessWidget {
  const _InkPill(
      {required this.label,
      required this.onTap,
      this.light = false,
      this.compact = false});
  final String label;
  final VoidCallback onTap;
  final bool light;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = light || compact ? Colors.white : JamJotColors.ink;
    final fg = light || compact ? JamJotColors.ink : Colors.white;
    return Semantics(
      button: true,
      child: Container(
        width: compact ? null : double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: JamJotColors.ink, width: 3),
          boxShadow: compact
              ? null
              : const [
                  BoxShadow(color: JamJotColors.ink, offset: Offset(4, 4))
                ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: compact
                  ? const EdgeInsets.symmetric(horizontal: 18, vertical: 8)
                  : const EdgeInsets.symmetric(vertical: 16),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: JamJotType.title,
                      fontSize: compact ? 15 : 19,
                      color: fg)),
            ),
          ),
        ),
      ),
    );
  }
}
