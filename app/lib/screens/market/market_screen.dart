import 'package:flutter/material.dart';

import '../../theme/jamjot_theme.dart';

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

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
              Text('Market',
                  style: text.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'The farmers' market — stands, berries, and My Shelf — opens when rewards go live.',
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
