import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jamjot/screens/market/market_screen.dart';
import 'package:jamjot/screens/home/home_screen.dart';
import 'package:jamjot/state/app_state.dart';
import 'package:jamjot/theme/jamjot_theme.dart';
import 'package:jamjot/widgets/letter_avatar.dart';
import 'market_fixture.dart';
import 'package:jamjot/widgets/coin_reward_host.dart';
import 'package:jamjot/widgets/coin_pouch.dart';

final fixture = MarketFixture();
final router = GoRouter(initialLocation: '/market', routes: [
  GoRoute(path: '/market', builder: (_, __) => const MarketScreen()),
  GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
  GoRoute(
      path: '/profiles',
      builder: (_, __) => const Center(
          child: Text('Fictional profile · no account connected.'))),
]);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
      url: 'https://jamjot-market-preview.invalid',
      publishableKey: 'fictional-only',
      httpClient: fixture.client,
      authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false, persistSession: false));
  runApp(ProviderScope(
      overrides: fixture.overrides(), child: const MarketPreview()));
}

class MarketPreview extends ConsumerWidget {
  const MarketPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = ref.watch(activeStudentProvider);
    return MaterialApp.router(
        title: 'JamJot • Avatar market preview',
        debugShowCheckedModeBanner: false,
        theme: buildJamJotTheme(
            student == null ? JamJotSkin.grownup : JamJotSkin.kid),
        routerConfig: router,
        builder: (context, child) => CoinRewardHost(
                child: Scaffold(
                    body: Column(children: [
              SafeArea(
                  bottom: false,
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Local preview · Fictional coins'),
                            TextButton(
                                onPressed: () => router.go('/market'),
                                child: const Text('Market')),
                            TextButton(
                                onPressed: () => router.go('/home'),
                                child: const Text('Home')),
                            TextButton(
                                onPressed: () => ref
                                        .read(activeStudentProvider.notifier)
                                        .state =
                                    student == null
                                        ? {...fixture.student}
                                        : null,
                                child: Text(student == null
                                    ? 'View as child'
                                    : 'View as grown-up')),
                            if (student != null)
                              TextButton.icon(
                                  onPressed: () {
                                    fixture.coins += 5;
                                    ref.invalidate(berryBalanceProvider(
                                        marketPreviewStudent));
                                  },
                                  icon: const JamCoin(size: 20),
                                  label: const Text('Earn 5 coins')),
                            LetterAvatar(
                                name: 'Melody',
                                avatarKey: student?['avatar_key'] as String?),
                          ]))),
              Expanded(child: child!),
            ]))));
  }
}
