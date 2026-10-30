import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth/add_student_screen.dart';
import 'screens/auth/gate_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/auth/teacher_setup_screen.dart';
import 'screens/auth/title_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/market/market_screen.dart';
import 'screens/practice/practice_screen.dart';
import 'screens/profile/profile_picker_screen.dart';
import 'screens/shell.dart';
import 'services/supabase_service.dart';
import 'theme/jamjot_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JamJotBackend.init();
  runApp(const ProviderScope(child: JamJotApp()));
}

/// Pokes the router whenever sign-in state changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh() {
    JamJotBackend.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

final _router = GoRouter(
  initialLocation: JamJotBackend.signedIn ? '/gate' : '/',
  refreshListenable: _AuthRefresh(),
  redirect: (context, state) {
    final signedIn = JamJotBackend.signedIn;
    final loc = state.matchedLocation;
    const public = {'/', '/signin'};
    if (!signedIn && !public.contains(loc)) return '/';
    if (signedIn && public.contains(loc)) return '/gate';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const TitleScreen()),
    GoRoute(
      path: '/signin',
      builder: (_, state) => SignInScreen(
        startInCreateMode: state.uri.queryParameters['create'] == '1',
      ),
    ),
    GoRoute(path: '/gate', builder: (_, __) => const GateScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(
        path: '/add-student', builder: (_, __) => const AddStudentScreen()),
    GoRoute(
        path: '/teacher-setup',
        builder: (_, __) => const TeacherSetupScreen()),
    GoRoute(
        path: '/profiles', builder: (_, __) => const ProfilePickerScreen()),
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
