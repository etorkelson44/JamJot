import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../services/session_flags.dart';
import '../services/practice_navigation.dart';
import '../theme/jamjot_theme.dart';
import '../widgets/jamjot_icons.dart';
import '../widgets/letter_avatar.dart';

/// The bottom-tab shell. Tabs follow who's signed in:
/// kids:      Home · Practice · Market · Calendar
/// grown-ups: Home · Library · Market · Calendar
/// (Grown-ups don't practice themselves — each kid's practice lives on
/// that kid's page, where off-app practices can be logged too.)
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // Branch order in the router: 0 home, 1 practice, 2 library, 3 market,
  // 4 calendar, 5 ensemble.
  static const _kidBranches = [0, 1, 5, 3, 4];
  static const _grownUpBranches = [0, 2, 3, 4];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  Timer? _idleCheck;
  StatefulNavigationShell get shell => widget.shell;

  @override
  void initState() {
    super.initState();
    // Every minute: if the tab has been idle too long with a kid signed in,
    // return to the profile picker.
    _idleCheck = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      if (ref.read(activeStudentProvider) == null) return;
      final fresh = freshActiveStudent(kidSessionIdle);
      if (fresh == null || fresh == grownUpSession) {
        ref.read(activeStudentProvider.notifier).state = null;
        storeActiveStudent(null);
        if (mounted) context.go('/profiles');
      }
    });
  }

  @override
  void dispose() {
    _idleCheck?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKid = ref.watch(activeStudentProvider) != null;
    final branches = isKid ? AppShell._kidBranches : AppShell._grownUpBranches;
    var selected = branches.indexOf(shell.currentIndex);
    if (selected < 0) selected = 0; // current branch hidden for this role

    final destinations = isKid
        ? const [
            NavigationDestination(icon: Icon(JamJotIcons.home), label: 'Home'),
            NavigationDestination(
                icon: Icon(JamJotIcons.practice), label: 'Practice'),
            NavigationDestination(
                icon: Icon(Icons.theater_comedy_outlined), label: 'Ensemble'),
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

    return Listener(
      onPointerDown: (_) {
        if (isKid) touchActiveSession();
      },
      child: Scaffold(
      body: Stack(children: [
        shell,
        // The profile chip in the top-right corner: anywhere in the app it
        // brings you home; on Home itself it opens the profile switcher.
        Positioned(
          top: 0,
          right: 10,
          child: SafeArea(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              // The Jam Jar rides beside the profile chip on kid pages.
              if (isKid) ...[
                _JarChip(
                  studentId: ref.watch(activeStudentProvider)?['id'] as String?,
                  onTap: () async {
                    if (shell.currentIndex == 1) {
                      final guard =
                          ref.read(practiceExitGuardProvider).beforeLeave;
                      if (guard != null && !await guard()) return;
                      if (!context.mounted) return;
                    }
                    shell.goBranch(3); // the Market
                  },
                ),
                const SizedBox(width: 8),
              ],
              _ProfileChip(
              onHome: shell.currentIndex == 0,
              onTap: () async {
                if (shell.currentIndex == 0) {
                  context.go('/profiles');
                  return;
                }
                if (shell.currentIndex == 1) {
                  final guard =
                      ref.read(practiceExitGuardProvider).beforeLeave;
                  if (guard != null && !await guard()) return;
                  if (!context.mounted) return;
                }
                shell.goBranch(0);
              },
            ),
            ]),
          ),
        ),
      ]),
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
    ),
    );
  }
}


/// The round profile icon that rides in the top-right corner of every
/// page: the kid's own avatar (or the grown-up's initial), ringed in ink.
class _ProfileChip extends ConsumerWidget {
  const _ProfileChip({required this.onTap, required this.onHome});
  final VoidCallback onTap;
  final bool onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kid = ref.watch(activeStudentProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final name = kid?['display_name'] as String? ??
        profile?['display_name'] as String? ??
        '?';
    final label = onHome ? 'Switch profile' : 'Back to Home';
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(
              side: BorderSide(color: JamJotColors.ink, width: 2)),
          elevation: 2,
          shadowColor: Colors.black26,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: LetterAvatar(
                name: name,
                size: 34,
                avatarKey: kid?['avatar_key'] as String?,
                starterDefault: kid != null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// The Jam Jar companion to the profile chip: same scale, same corner,
/// the kid's coins at a glance. Tapping it opens the Market.
class _JarChip extends ConsumerWidget {
  const _JarChip({required this.studentId, required this.onTap});
  final String? studentId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (studentId == null) return const SizedBox.shrink();
    final balance =
        ref.watch(berryBalanceProvider(studentId!)).valueOrNull;
    return Semantics(
      button: true,
      label: 'Jam Jar, ${balance ?? 0} coins. Open the Market',
      child: Tooltip(
        message: 'Your Jam Jar · open the Market',
        child: Material(
          color: Colors.white,
          shape: const StadiumBorder(
              side: BorderSide(color: JamJotColors.ink, width: 2)),
          elevation: 2,
          shadowColor: Colors.black26,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                ExcludeSemantics(
                    child: Image.asset('assets/art/jar_closed.png',
                        height: 28, fit: BoxFit.contain)),
                const SizedBox(width: 5),
                Text('${balance ?? '…'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: JamJotColors.ink)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
