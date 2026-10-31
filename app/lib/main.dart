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
import 'screens/family/kid_detail_screen.dart';
import 'screens/history/practice_history_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/lessons/lesson_builder_screen.dart';
import 'screens/invite/invite_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/messages/messages_screen.dart';
import 'screens/teaching/teaching_screen.dart';
import 'screens/market/market_screen.dart';
import 'screens/practice/practice_screen.dart';
import 'screens/practice/practice_session_screen.dart';
import 'screens/profile/my_profile_screen.dart';
import 'screens/profile/profile_picker_screen.dart';
import 'screens/shell.dart';
import 'services/supabase_service.dart';
import 'theme/jamjot_theme.dart';

/// True when the app was opened from the email-confirmation link.
bool _cameFromEmailConfirmation = false;

/// True when the link had already been used or had expired.
bool _confirmationLinkStale = false;

/// Where a confirmation landing should take people.
String _confirmationLanding() => _confirmationLinkStale
    ? '/signin?expired=1'
    : (_cameFromEmailConfirmation ? '/signin?confirmed=1' : '/');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Peek at the launch URL before Supabase consumes it.
  final launch = Uri.base.toString();
  _cameFromEmailConfirmation = launch.contains('type=signup');
  _confirmationLinkStale = launch.contains('otp_expired') ||
      launch.contains('access_denied') ||
      launch.contains('error_code');
  await JamJotBackend.init();
  if (_cameFromEmailConfirmation) {
    // The link signs people in automatically; we want them to sign in
    // themselves from a friendly "email confirmed" page instead.
    try {
      await JamJotBackend.client.auth.signOut();
    } catch (_) {/* fine — they simply were not signed in */}
  }
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
  initialLocation: (_cameFromEmailConfirmation || _confirmationLinkStale)
      ? _confirmationLanding()
      : (JamJotBackend.signedIn ? '/gate' : '/'),
  refreshListenable: _AuthRefresh(),
  // The confirmation link arrives carrying security tokens as a strange
  // address the router does not know — land those on the sign-in page
  // instead of a broken screen.
  onException: (_, state, router) =>
      router.go(_confirmationLanding()),
  redirect: (context, state) {
    final loc = state.matchedLocation;
    // Token-bearing or error-bearing launch addresses → sign-in landing.
    if (loc.contains('access_token') ||
        loc.contains('error_code') ||
        loc.contains('otp_expired')) {
      return _confirmationLanding();
    }
    final signedIn = JamJotBackend.signedIn;
    const public = {'/', '/signin', '/invite'};
    if (!signedIn && !public.contains(loc)) return '/';
    if (signedIn && (loc == '/' || loc == '/signin')) return '/gate';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const TitleScreen()),
    GoRoute(
      path: '/signin',
      builder: (_, state) => SignInScreen(
        startInCreateMode: state.uri.queryParameters['create'] == '1',
        emailJustConfirmed: state.uri.queryParameters['confirmed'] == '1',
        linkExpired: state.uri.queryParameters['expired'] == '1',
        intendedRole: state.uri.queryParameters['role'],
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
    GoRoute(
        path: '/practice-session',
        builder: (_, __) => const PracticeSessionScreen()),
    GoRoute(path: '/library', builder: (_, __) => const LibraryScreen()),
    GoRoute(path: '/teaching', builder: (_, __) => const TeachingScreen()),
    GoRoute(path: '/messages', builder: (_, __) => const MessagesScreen()),
    GoRoute(
        path: '/my-profile', builder: (_, __) => const MyProfileScreen()),
    GoRoute(
      path: '/kid',
      builder: (_, state) => KidDetailScreen(
          studentId: state.uri.queryParameters['student'] ?? ''),
    ),
    GoRoute(
      path: '/chat',
      builder: (_, state) => ChatScreen(
        enrollmentId: state.uri.queryParameters['enrollment'] ?? '',
        title: state.uri.queryParameters['title'] ?? 'Chat',
        iAmPrimary: state.uri.queryParameters['primary'] == '1',
        teacherProfileId: state.uri.queryParameters['teacher'] ?? '',
      ),
    ),
    GoRoute(
      path: '/invite',
      builder: (_, state) =>
          InviteScreen(token: state.uri.queryParameters['token'] ?? ''),
    ),
    GoRoute(
      path: '/history',
      builder: (_, state) => PracticeHistoryScreen(
        studentId: state.uri.queryParameters['student'] ?? '',
        studentName: state.uri.queryParameters['name'] ?? 'My',
      ),
    ),
    GoRoute(
      path: '/lesson-builder',
      builder: (_, state) => LessonBuilderScreen(
        studentId: state.uri.queryParameters['student'] ?? '',
        studentName: state.uri.queryParameters['name'] ?? 'Student',
        enrollmentId: state.uri.queryParameters['enrollment'],
        sectionLabel: state.uri.queryParameters['section'],
      ),
    ),
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
