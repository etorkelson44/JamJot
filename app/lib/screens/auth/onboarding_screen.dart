import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/jamjot_theme.dart';
import '../../widgets/jamjot_card.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Getting set up')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('How will you use JamJot?',
                      style: text.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('You can always add the other role later.',
                      style: text.bodyMedium
                          ?.copyWith(color: JamJotColors.inkSoft)),
                  const SizedBox(height: 24),
                  JamJotCard(
                    emoji: '🧑‍🧒',
                    tint: JamJotColors.blueberryTint,
                    title: 'I am a parent or caregiver',
                    subtitle:
                        'Set up profiles for my kids and cheer on their practice.',
                    onTap: () => context.go('/add-student'),
                  ),
                  const SizedBox(height: 16),
                  JamJotCard(
                    emoji: '🎻',
                    tint: JamJotColors.marigoldTint,
                    title: 'I am a music teacher',
                    subtitle:
                        'Build lessons and assignments, and hear real practice.',
                    onTap: () => context.go('/teacher-setup'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
