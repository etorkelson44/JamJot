import 'package:flutter/material.dart';

import '../../theme/jamjot_theme.dart';
import '../../widgets/jamjot_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text('Hi there! 👋',
              style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          Text('JamJot is under construction — screens light up as they land.',
              style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft)),
          const SizedBox(height: 16),
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
                'Sign-in & kid profiles → the practice timer with recording → berries in the jar.',
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
      ),
    );
  }
}
