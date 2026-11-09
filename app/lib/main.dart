import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth/add_student_screen.dart';
import 'screens/auth/gate_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/auth/teacher_setup_screen.dart';
import 'screens/auth/title_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/ensemble/my_ensemble_screen.dart';
import 'screens/family/kid_detail_screen.dart';
import 'screens/history/practice_history_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/lessons/lesson_builder_screen.dart';
import 'screens/invite/invite_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/lesson/lesson_sheet_screen.dart';
import 'screens/messages/messages_screen.dart';
import 'screens/teaching/teaching_screen.dart';
import 'screens/market/market_screen.dart';
import 'screens/practice/practice_screen.dart';
import 'screens/practice/practice_session_screen.dart';
import 'screens/profile/my_profile_screen.dart';
import 'screens/profile/profile_picker_screen.dart';
import 'screens/shell.dart';
import 'services/page_nav.dart';
import 'services/session_flags.dart';
import 'state/app_state.dart';
import 'widgets/coin_reward_host.dart';
import 'widgets/jammed_up.dart';
import 'services/supabase_service.dart';
import 'theme/jamjot_theme.dart';

/// True when the app was opened from the email-confirmation link.
bool _cameFromEmailConfirmation = false;

/// True when the link had already been used or had expired.
bool _confirmationLinkStale = false;

/// True when opened from a forgot-password email (keeps its session!).
bool _cameFromPasswordRecovery = false;

/// Where a confirmation landing should take people.
String _confirmationLanding() => _cameFromPasswordRecovery
    ? '/reset-password'
    : _confirmationLinkStale
        ? '/signin?expired=1'
        : (_cameFromEmailConfirmation ? '/signin?confirmed=1' : '/');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // If any screen crashes while drawing, show Maestro instead of a blank or
  // grey box. (Debug builds keep Flutter's own red error screen for
  // developers.)
  if (kReleaseMode) {
    ErrorWidget.builder =
        (_) => const JammedUp(onRetry: reloadPage, onHome: goToStartPage);
  }
  try {
    await _startUp();
  } catch (e, st) {
    // The app couldn't even start (say the backend couldn't be reached):
    // show the jammed-up page instead of a blank one.
    debugPrint('JamJot could not start: $e\n$st');
    runApp(const JammedApp());
    return;
  }
  runApp(const ProviderScope(child: JamJotApp()));
}

/// Everything that has to happen before the first screen can draw.
Future<void> _startUp() async {
  // Peek at the launch URL before Supabase consumes it.
  final launch = Uri.base.toString();
  _cameFromEmailConfirmation = launch.contains('type=signup');
  _cameFromPasswordRecovery = launch.contains('type=recovery');
  _confirmationLinkStale = launch.contains('otp_expired') ||
      launch.contains('access_denied') ||
      launch.contains('error_code');
  await JamJotBackend.init();
  // "Stay signed in" was unchecked and the browser was closed since:
  // end the session now, before anything renders.
  if (JamJotBackend.signedIn &&
      !keepSignedIn &&
      !thisTabSignedIn &&
      !_cameFromEmailConfirmation &&
      !_cameFromPasswordRecovery) {
    try {
      await JamJotBackend.client.auth.signOut();
    } catch (_) {}
  }
  if (JamJotBackend.signedIn) markThisTabSignedIn();
  if (_cameFromEmailConfirmation && !_cameFromPasswordRecovery) {
    // The link signs people in automatically; we want them to sign in
    // themselves from a friendly "email confirmed" page instead.
    try {
      await JamJotBackend.client.auth.signOut();
    } catch (_) {/* fine — they simply were not signed in */}
  }
}

/// Shown instead of the app when it can't start at all. Needs no backend,
/// router or providers, so nothing in it can be the thing that's broken.
class JammedApp extends StatelessWidget {
  const JammedApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'JamJot',
        debugShowCheckedModeBanner: false,
        // A plain theme on purpose: the app's own theme fetches web fonts.
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(
            body: JammedUp(onRetry: reloadPage, onHome: goToStartPage)),
      );
}

/// Whether the launch-time routing decision has been made.
bool _bootRouted = false;

/// Pokes the router whenever sign-in state changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh() {
    JamJotBackend.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

final _router = GoRouter(
  initialLocation: (_cameFromEmailConfirmation ||
          _confirmationLinkStale ||
          _cameFromPasswordRecovery)
      ? _confirmationLanding()
      : (JamJotBackend.signedIn ? '/gate' : '/'),
  refreshListenable: _AuthRefresh(),
  // The confirmation link arrives carrying security tokens as a strange
  // address the router does not know — land those on the sign-in page
  // instead of a broken screen. Any other address that doesn't exist gets
  // the friendly "jammed up" page.
  onException: (_, state, router) {
    final address = state.uri.toString();
    final isEmailLanding = address.contains('access_token') ||
        address.contains('refresh_token') ||
        address.contains('error_code') ||
        address.contains('otp_expired') ||
        address.contains('access_denied') ||
        address.contains('type=signup') ||
        address.contains('type=recovery');
    router.go(isEmailLanding ? _confirmationLanding() : '/jammed');
  },
  errorBuilder: (context, state) =>
      JammedUp(onHome: () => context.go('/')),
  redirect: (context, state) {
    final loc = state.matchedLocation;
    // On every fresh app launch, land on the profile picker — even when the
    // browser tries to restore whatever page was open last time.
    if (!_bootRouted) {
      _bootRouted = true;
      if (JamJotBackend.signedIn &&
          loc != '/gate' &&
          loc != '/invite' &&
          loc != '/reset-password') {
        // Remember where they were: if their session is still fresh, the
        // gate sends them straight back instead of the profile picker.
        if (loc != '/' &&
            loc != '/signin' &&
            !loc.contains('access_token') &&
            !loc.contains('error_code')) {
          bootTarget = state.uri.toString();
        }
        return '/gate';
      }
    }
    // Token-bearing or error-bearing launch addresses → sign-in landing.
    if (loc.contains('access_token') ||
        loc.contains('error_code') ||
        loc.contains('otp_expired')) {
      return _confirmationLanding();
    }
    final signedIn = JamJotBackend.signedIn;
    const public = {'/', '/signin', '/invite', '/jammed'};
    if (!signedIn && !public.contains(loc)) return '/';
    if (signedIn && (loc == '/' || loc == '/signin')) return '/gate';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const TitleScreen()),
    // Where an address that doesn't exist lands (see onException above).
    GoRoute(
      path: '/jammed',
      builder: (context, __) => JammedUp(onHome: () => context.go('/')),
    ),
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
    GoRoute(path: '/teaching', builder: (_, __) => const TeachingScreen()),
    GoRoute(path: '/messages', builder: (_, __) => const MessagesScreen()),
    GoRoute(
        path: '/account', builder: (_, __) => const MyProfileScreen()),
    GoRoute(
        path: '/reset-password',
        builder: (_, __) => const ResetPasswordScreen()),
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
      path: '/lesson-sheet',
      builder: (_, state) => LessonSheetScreen(
        studentId: state.uri.queryParameters['student'] ?? '',
        studentName: state.uri.queryParameters['name'] ?? 'Student',
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
          GoRoute(path: '/library', builder: (_, __) => const LibraryScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/market', builder: (_, __) => const MarketScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/ensemble',
              builder: (_, __) => const MyEnsembleScreen()),
        ]),
      ],
    ),
  ],
);

class JamJotApp extends ConsumerStatefulWidget {
  const JamJotApp({super.key});

  @override
  ConsumerState<JamJotApp> createState() => _JamJotAppState();
}

class _JamJotAppState extends ConsumerState<JamJotApp>
    with WidgetsBindingObserver {
  DateTime? _hiddenAt;

  /// Away longer than this and the app relocks to the profile picker.
  static const _relockAfter = Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  bool _maestroLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load perplexed Maestro now, so the jammed-up screen shows him even if
    // the connection drops before anything goes wrong.
    if (!_maestroLoaded) {
      _maestroLoaded = true;
      precacheImage(const AssetImage(JammedUp.artAsset), context,
          onError: (_, __) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _hiddenAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final hiddenAt = _hiddenAt;
      _hiddenAt = null;
      if (hiddenAt != null &&
          DateTime.now().difference(hiddenAt) > _relockAfter &&
          JamJotBackend.signedIn) {
        _router.go('/gate');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'JamJot',
      debugShowCheckedModeBanner: false,
      // Skin follows who's driving: kid profile active → The Jam Stand;
      // grown-up (caregiver/teacher) → Calm Studio. Erika's picks, Nov 3 2026.
      theme: buildJamJotTheme(ref.watch(activeStudentProvider) == null
          ? JamJotSkin.grownup
          : JamJotSkin.kid),
      routerConfig: _router,
      builder: (context, child) => CoinRewardHost(child: child!),
    );
  }
}
