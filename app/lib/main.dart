import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth/title_screen.dart';
import 'screens/shell.dart';
import 'screens/home/home_screen.dart';
import 'screens/practice/practice_screen.dart';
import 'screens/market/market_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'services/supabase_service.dart';
import 'theme/jamjot_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JamJotBackend.init();
  runApp(const ProviderScope(child: JamJotApp()));
}

final _router = GoRouter(
  initialLocation: JamJotBackend.signedIn ? '/home' : '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const TitleScreen()),
    StatefulShellRoute.indexedStack(
      builder: (_, __, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/practice', builder: (_, __) => const PracticeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/market', builder: (_, __) => const MarketScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
        ]),
      ],
    ),
  ],
);

class JamJotApp extends StatelessWidget {
  const JamJotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'JamJot',
      debugShowCheckedModeBanner: false,
      theme: buildJamJotTheme(),
      routerConfig: _router,
    );
  }
}
