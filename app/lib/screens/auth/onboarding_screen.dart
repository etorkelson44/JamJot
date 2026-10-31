import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_service.dart';

import '../../theme/jamjot_theme.dart';
import '../../widgets/jamjot_card.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Getting set up'),
        actions: [
          TextButton(
            onPressed: () async {
              await JamJotBackend.client.auth.signOut();
              if (context.mounted) context.go('/');
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
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
                    title: 'I am a family grown-up',
                    subtitle:
                        'Parent, guardian, or caregiver. Set up kid profiles inside this account — connect a teacher or studio later with their invite.',
                    onTap: () => context.go('/add-student'),
                  ),
                  const SizedBox(height: 16),
                  JamJotCard(
                    emoji: '🎻',
                    tint: JamJotColors.marigoldTint,
                    title: 'I teach music',
                    subtitle:
                        'On my own, running a studio, or joining one — all start here.',
                    onTap: () => context.go('/teacher-setup'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Good to know: kids never need their own accounts or emails. They live as profiles inside a grown-up account, each protected by a PIN.',
                    style:
                        text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
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
