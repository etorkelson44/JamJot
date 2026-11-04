import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamjot/screens/practice/practice_session_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/practice_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = PracticeFixture();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => '/private/tmp');
    await Supabase.initialize(
        url: 'https://jamjot-test.invalid',
        publishableKey: 'test-key',
        httpClient: fixture.client,
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false, persistSession: false));
  });
  Future<void> open(WidgetTester tester, FakeRecorder recorder,
      {double scale = 1}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: fixture.overrides(recorder),
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: const PracticeSessionScreen())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Piano song'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Piano song'), findsAtLeastNWidgets(1),
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '));
    await tester.tap(find.text('Piano song').first);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'one-minute completion prompts for song goal and saves only fresh seconds',
      (tester) async {
    fixture.initialSeconds = 60;
    final recorder = FakeRecorder();
    await open(tester, recorder);
    await tester.tap(find.text('Done with this song'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 minute goal'), findsOneWidget);
    expect(find.textContaining('save and move on'), findsOneWidget);
    await tester.tap(find.text('Save & move on'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Getting there'));
    await tester.pumpAndSettle();
    expect(fixture.inserts.last['seconds'],
        0); // Earlier 60 seconds are already persisted.
    expect(fixture.inserts.last['completed'], true);
    expect(find.text('🎉 Piano song done!'), findsOneWidget);
  });
  testWidgets(
      'under-minute dialog remains usable with large text and keeps progress',
      (tester) async {
    fixture.initialSeconds = 30;
    await open(tester, FakeRecorder(), scale: 2);
    await tester.tap(find.text('Done with this song'));
    await tester.pumpAndSettle();
    expect(find.textContaining('at least 1 minute'), findsOneWidget);
    final back = find.text('Keep progress & return to songs');
    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('Almost there!'), findsNothing);
    await tester.scrollUntilVisible(find.text('Piano song'),250,scrollable:find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Piano song'), findsAtLeastNWidgets(1));
  });
  testWidgets('failed song save preserves progress and never celebrates',
      (tester) async {
    fixture.initialSeconds = 60;
    fixture.failSave = true;
    addTearDown(() => fixture.failSave = false);
    await open(tester, FakeRecorder());
    await tester.tap(find.text('Done with this song'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save & move on'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Getting there'));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be saved'), findsOneWidget);
    expect(find.text('🎉 Piano song done!'), findsNothing);
    expect(find.text('Done with this song'), findsOneWidget);
  });
}
