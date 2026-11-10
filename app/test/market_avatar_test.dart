import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jamjot/models/market_avatars.dart';
import 'package:jamjot/screens/market/market_screen.dart';
import 'package:jamjot/screens/home/home_screen.dart';
import 'package:jamjot/state/app_state.dart';
import 'package:jamjot/widgets/dressed_avatar.dart';
import '../tool/market_fixture.dart';

/// The JamJot stand (where avatars are sold) is closed while the band gets
/// ready for the World Tour, so the avatar buy flow is not on screen. These
/// tests are kept, skipped, for when avatars go back on sale.
const _jamStandClosed = true; // flip to false when avatars go back on sale

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = MarketFixture();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://market-test.invalid',
        publishableKey: 'test-key',
        httpClient: fixture.client,
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false, persistSession: false));
  });
  setUp(fixture.reset);
  Future<void> open(WidgetTester tester,
      {double scale = 1, double width = 375, bool home = false}) async {
    tester.view.physicalSize = Size(width, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: fixture.overrides(),
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                body: home ? const HomeScreen() : const MarketScreen()))));
    await tester.pump(const Duration(milliseconds: 300));
    if (home) {
      // The Home screen has endless animations, so it never "settles".
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> buyFirst(WidgetTester tester) async {
    final buy = find.text('Buy').first;
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy for 25 coins'));
    await tester.pumpAndSettle();
  }

  testWidgets('the JamJot stand is closed and sells no avatars',
      (tester) async {
    await open(tester);
    expect(find.textContaining('The JamJot stand is closed'), findsOneWidget);
    expect(find.text('Buy'), findsNothing);
    expect(fixture.purchaseCalls, 0);
  });
  test(
      'catalog preserves server IDs/prices and does not duplicate existing avatars',
      () {
    final row = {
      ...fixture.items.singleWhere((item) => item['asset_key'] == 'strawberry'),
      'price': 37
    };
    final live = presentMarketItems([row]);
    expect(live.single['title'], 'Ms. Straw-ccato');
    expect(live.single['id'], row['id']);
    expect(live.single['price'], 37);
    final review = presentMarketItems([row], includeUpcoming: true);
    expect(review.length, musicalAvatars.length);
    expect(review.last['upcoming'], true);
    expect(presentMarketItems(fixture.items, includeUpcoming: true).length,
        musicalAvatars.length);
    expect(row['title'], 'Rockstar Strawberry');
  });
  testWidgets('supplied artwork and names fit a small screen with large text',
      (tester) async {
    await open(tester, scale: 2);
    for (final name in [
      'Señor Jalapresto',
      'Ms. Straw-ccato',
      'Grape Arpeggio',
      'Lemon Sharp'
    ]) {
      await tester.scrollUntilVisible(find.text(name), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text(name), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .where((i) => i.image is AssetImage)
        .map((i) => (i.image as AssetImage).assetName);
    expect(
        assets,
        containsAll([
          'assets/art/avatar_jalapeno.png',
          'assets/art/avatar_strawberry.png',
          'assets/art/avatar_grape.png',
          'assets/art/avatar_lemon.png'
        ]));
  }, skip: _jamStandClosed);
  testWidgets('purchase spends once, fills the shelf and wears the character',
      (tester) async {
    fixture.coins = 100;
    await open(tester, width: 1100);
    await buyFirst(tester);
    expect(fixture.coins, 75);
    expect(fixture.shelf.length, 1);
    expect(fixture.purchaseCalls, 1);
    expect(fixture.student['avatar_key'], 'jalapeno');
    await tester.tap(find.text('🎉'));
    await tester.pumpAndSettle();
    expect(find.text('Wearing ✓'), findsAtLeastNWidgets(1));
    final scope =
        ProviderScope.containerOf(tester.element(find.byType(MarketScreen)));
    expect(scope.read(activeStudentProvider)?['avatar_key'], 'jalapeno');
    await buyFirst(tester); // Ms. Straw-ccato is next in the catalog.
    expect(fixture.coins, 50);
    expect(fixture.shelf.length, 2);
    await tester.tap(find.text('🎉'));
    await tester.pumpAndSettle();
    final wear = find.text('Wear it').first;
    await tester.ensureVisible(wear);
    await tester.tap(wear);
    await tester.pumpAndSettle();
    expect(fixture.student['avatar_key'], 'jalapeno');
    expect(fixture.coins, 50);
    expect(fixture.purchaseCalls, 2);
    await buyFirst(tester); // Grape Arpeggio is next in the catalog.
    expect(fixture.coins, 25);
    expect(fixture.shelf.length, 3);
    expect(fixture.student['avatar_key'], 'grape');
    await tester.tap(find.text('🎉'));
    await tester.pumpAndSettle();
    expect(scope.read(activeStudentProvider)?['avatar_key'], 'grape');
    await buyFirst(tester); // Lemon Sharp is the remaining unowned avatar.
    expect(fixture.coins, 0);
    expect(fixture.shelf.length, 4);
    expect(fixture.purchaseCalls, 4);
    expect(fixture.student['avatar_key'], 'lemon');
    await tester.tap(find.text('🎉'));
    await tester.pumpAndSettle();
    expect(scope.read(activeStudentProvider)?['avatar_key'], 'lemon');
  }, skip: _jamStandClosed);
  testWidgets('insufficient coins leave ownership and balance unchanged',
      (tester) async {
    fixture.coins = 10;
    await open(tester);
    await buyFirst(tester);
    expect(fixture.coins, 10);
    expect(fixture.shelf, isEmpty);
    expect(find.textContaining('Not enough coins'), findsOneWidget);
  }, skip: _jamStandClosed);
  testWidgets('failed purchase never claims ownership or spends coins',
      (tester) async {
    fixture.failPurchase = true;
    await open(tester);
    await buyFirst(tester);
    expect(fixture.coins, 75);
    expect(fixture.shelf, isEmpty);
    expect(find.text('Purchase unavailable'), findsOneWidget);
    expect(find.text('Wearing ✓'), findsNothing);
  }, skip: _jamStandClosed);
  testWidgets('cancel does not make a purchase request', skip: _jamStandClosed,
      (tester) async {
    await open(tester);
    final buy = find.text('Buy').first;
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not yet'));
    await tester.pumpAndSettle();
    expect(fixture.purchaseCalls, 0);
    expect(fixture.coins, 75);
  });
  testWidgets('Home profile shows the purchased placeholder image',
      (tester) async {
    fixture.student['avatar_key'] = 'lemon';
    await open(tester, home: true);
    // Home can show several characters; the worn one must be among them.
    expect(
        tester
            .widgetList<DressedAvatar>(find.byType(DressedAvatar))
            .any((d) => d.avatarKey == 'lemon'),
        isTrue);
    expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/art/avatar_lemon.png'),
        findsAtLeastNWidgets(1));
  });
}
