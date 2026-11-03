import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../services/practice_navigation.dart';
import '../theme/jamjot_theme.dart';
import '../widgets/jamjot_icons.dart';

/// The bottom-tab shell. Tabs follow who's signed in:
/// kids:      Home · Practice · Market · Calendar
/// grown-ups: Home · Library · Market · Calendar
/// (Grown-ups don't practice themselves — each kid's practice lives on
/// that kid's page, where off-app practices can be logged too.)
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // Branch order in the router: 0 home, 1 practice, 2 library, 3 market,
  // 4 calendar.
  static const _kidBranches = [0, 1, 3, 4];
  static const _grownUpBranches = [0, 2, 3, 4];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKid = ref.watch(activeStudentProvider) != null;
    final branches = isKid ? _kidBranches : _grownUpBranches;
    var selected = branches.indexOf(shell.currentIndex);
    if (selected < 0) selected = 0; // current branch hidden for this role

    final destinations = isKid
        ? const [
            NavigationDestination(icon: Icon(JamJotIcons.home), label: 'Home'),
            NavigationDestination(
                icon: Icon(JamJotIcons.practice), label: 'Practice'),
            NavigationDestination(
                icon: Icon(JamJotIcons.market), label: 'Market'),
            NavigationDestination(
                icon: Icon(JamJotIcons.calendar), label: 'Calendar'),
          ]
        : const [
            NavigationDestination(icon: Icon(JamJotIcons.home), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.library_music_outlined), label: 'Library'),
            NavigationDestination(
                icon: Icon(JamJotIcons.market), label: 'Market'),
            NavigationDestination(
                icon: Icon(JamJotIcons.calendar), label: 'Calendar'),
          ];

    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: JamJotColors.ink, width: 2)),
        ),
        child: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (i) async {
            final target = branches[i];
            if (shell.currentIndex == 1 && target != 1) {
              final guard = ref.read(practiceExitGuardProvider).beforeLeave;
              if (guard != null && !await guard()) return;
              if (!context.mounted) return;
            }
            shell.goBranch(target,
                initialLocation: target == shell.currentIndex);
          },
          backgroundColor: Colors.white,
          destinations: destinations,
        ),
      ),
    );
  }
}
