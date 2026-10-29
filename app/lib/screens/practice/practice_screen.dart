import 'package:flutter/material.dart';

import '../../theme/jamjot_theme.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Practice',
                  style: text.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'The listening practice session lands here — mic-gated timer, song matching, berries.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
