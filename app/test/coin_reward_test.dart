import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/services/sound_gate.dart';
import 'package:jamjot/state/app_state.dart';
import 'package:jamjot/state/coin_rewards.dart';
import 'package:jamjot/widgets/coin_reward_host.dart';
import 'package:jamjot/widgets/coin_pouch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => soundGate.apply(null));

  test('earnings exclude initial loads, spending, retries and other profiles',
      () {
    final tracker = CoinRewardTracker();
    expect(tracker.observe('a', 75), 0);
    expect(tracker.observe('a', null), 0); // refresh or read failure
    expect(tracker.observe('a', 75), 0);
    expect(tracker.observe('a', 80), 5);
    expect(tracker.observe('a', 80), 0);
    expect(tracker.observe('a', 55), 0); // purchase
    expect(tracker.observe('a', 60), 5);
    expect(tracker.observe('b', 900), 0); // another child's balance
    expect(tracker.observe('b', 901), 1);
    expect(tracker.observe(null, null), 0);
    expect(tracker.observe('b', 901), 0); // returning to the child
    expect(tracker.observe('b', 899), 0); // corrected reward
  });

  var balance = 75, plays = 0;
  var failRead = false;
  late ProviderContainer container;
  Future<void> open(WidgetTester tester,
      {bool reduced = false,
      double scale = 1,
      Map<String, dynamic>? soundPrefs}) async {
    balance = 75;
    plays = 0;
    failRead = false;
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = ProviderContainer(overrides: [
      activeStudentProvider.overrideWith(
          (ref) => {'id': 'a', if (soundPrefs != null) 'sound_prefs': soundPrefs}),
      berryBalanceProvider('a').overrideWith((ref) async {
        if (failRead) throw StateError('Temporary read error');
        return balance;
      }),
      berryBalanceProvider('b').overrideWith((ref) async => 200),
      coinSoundPlayerProvider.overrideWithValue((_) {
        plays++;
      }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  disableAnimations: reduced,
                  textScaler: TextScaler.linear(scale)),
              child: CoinRewardHost(pollForUpdates: false, child: child!)),
          home: Scaffold(
              body: Builder(
                  builder: (context) => Column(children: [
                        const JamJar(studentId: 'a'),
                        const Spacer(),
                        TextButton(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => const Scaffold(
                                        body: JamJar(studentId: 'a')))),
                            child: const Text('Another page')),
                      ]))),
        )));
    await tester.pumpAndSettle();
  }

  Future<void> update(WidgetTester tester, int coins) async {
    balance = coins;
    container.invalidate(berryBalanceProvider('a'));
    try {
      await container.read(berryBalanceProvider('a').future);
    } catch (_) {}
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets('new rewards show once across navigation; spending stays quiet',
      (tester) async {
    await open(tester);
    expect(find.byType(FallingCoinJar), findsNothing);
    expect(plays, 0);
    await update(tester, 80);
    expect(find.text('+5 coins!'), findsOneWidget);
    expect(plays, 1);
    expect(tester.widget<FallingCoinJar>(find.byType(FallingCoinJar)).animate,
        true);
    await tester.tap(find.text('Another page'));
    await tester.pumpAndSettle();
    expect(find.byType(JamJar, skipOffstage: false), findsNWidgets(2));
    expect(plays, 1); // two mounted coin pots must not play two jingles
    await tester.pump(const Duration(seconds: 12));
    await update(tester, 55);
    expect(find.byType(FallingCoinJar), findsNothing);
    expect(plays, 1);
    await update(tester, 55);
    expect(plays, 1);
    await update(tester, 58);
    expect(find.text('+3 coins!'), findsOneWidget);
    expect(plays, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed refresh and retry do not lose the earnings baseline',
      (tester) async {
    await open(tester);
    failRead = true;
    await update(tester, 75);
    expect(plays, 0);
    failRead = false;
    await update(tester, 82);
    expect(find.text('+7 coins!'), findsOneWidget);
    expect(plays, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('rapid rewards merge visibly and profile switching clears them',
      (tester) async {
    await open(tester);
    await update(tester, 80);
    await update(tester, 90);
    expect(find.text('+15 coins!'), findsOneWidget);
    expect(plays, 2);
    container.read(activeStudentProvider.notifier).state = {'id': 'b'};
    await tester.pumpAndSettle();
    expect(find.byType(FallingCoinJar), findsNothing);
    expect(plays, 2);
    container.read(activeStudentProvider.notifier).state = null;
    await tester.pumpAndSettle();
    expect(find.byType(FallingCoinJar), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('muted reduced-motion reward is still readable at 2x text',
      (tester) async {
    await open(tester,
        reduced: true, scale: 2, soundPrefs: {'coins': false});
    await update(tester, 85);
    expect(plays, 0);
    expect(find.text('+10 coins!'), findsOneWidget);
    expect(tester.widget<FallingCoinJar>(find.byType(FallingCoinJar)).animate,
        false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the caregiver can silence every sound for a profile',
      (tester) async {
    await open(tester, soundPrefs: {'enabled': false});
    await update(tester, 80);
    expect(plays, 0);
    expect(find.text('+5 coins!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the jam jar is display-only and uses the supplied art',
      (tester) async {
    await open(tester);
    await tester.tap(find.byType(JamJar).first);
    await tester.pumpAndSettle();
    expect(find.text('Your Jam Jar'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(
        tester.widgetList<Image>(find.byType(Image)).any((w) =>
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/art/jar/closed.webp'),
        true);
    await tester.pumpWidget(const SizedBox());
  });

  test('sound gate: missing keys are on; master and per-effect switches win',
      () {
    final gate = SoundGate();
    expect(gate.allows('coins'), true);
    expect(gate.allows('cheer'), true);
    gate.apply({'cheer': false});
    expect(gate.allows('cheer'), false);
    expect(gate.allows('coins'), true);
    expect(gate.allows('coin'), true); // synthesized blip follows "coins"
    gate.apply({'coins': false});
    expect(gate.allows('coin'), false);
    gate.apply({'enabled': false, 'pop': true});
    expect(gate.masterOn, false);
    expect(gate.allows('pop'), false);
    gate.apply(null);
    expect(gate.allows('fanfare'), true);
    expect(soundEffectOptions.map((o) => o.key),
        containsAll(['coins', 'cheer', 'fanfare', 'pop']));
  });
}
