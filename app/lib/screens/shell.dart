import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/jamjot_theme.dart';
import '../widgets/jamjot_icons.dart';

/// The four-tab navigation shell: Home · Practice · Market · Calendar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: JamJotColors.ink, width: 2)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          backgroundColor: Colors.white,
          destinations: const [
            NavigationDestination(icon: Icon(JamJotIcons.home), label: 'Home'),
            NavigationDestination(
                icon: Icon(JamJotIcons.practice), label: 'Practice'),
            NavigationDestination(
                icon: Icon(JamJotIcons.market), label: 'Market'),
            NavigationDestination(
                icon: Icon(JamJotIcons.calendar), label: 'Calendar'),
          ],
        ),
      ),
    );
  }
}
