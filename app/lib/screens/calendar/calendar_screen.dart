import 'package:flutter/material.dart';

import '../../theme/jamjot_theme.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

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
              Text('Calendar',
                  style: text.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Lessons, events, and payment due-dates will populate here.',
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
