import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jamjot/services/backup_service.dart';
import 'package:jamjot/state/app_state.dart';
import 'package:jamjot/widgets/backup_settings.dart';

class FakeGateway extends BackupGateway {
  bool fail = false;
  @override
  String get accountId => 'fictional';
  @override
  bool get isPreview => true;
  @override
  Future<Uint8List> download(String password) async {
    if (fail) throw Exception('Missing file. No partial backup was saved.');
    return Uint8List.fromList([80, 75, 3, 4]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'reminders start off, use confirmed saves, snooze separately, isolate accounts',
      () async {
    final now = DateTime.utc(2026, 11, 4);
    expect((await BackupPreferences.read('a')).due(now), false);
    expect(const BackupPreferences(intervalDays: 7).due(now), true);
    expect(
        BackupPreferences(
                intervalDays: 7,
                lastSaved: now.subtract(const Duration(days: 7)))
            .due(now),
        true);
    expect(BackupPreferences(intervalDays: 7, lastSaved: now).due(now), false);
    final snoozed = BackupPreferences(
        intervalDays: 7, dismissedUntil: now.add(const Duration(days: 1)));
    expect(snoozed.due(now), false);
    expect(snoozed.due(now.add(const Duration(days: 1))), true);
    await BackupPreferences(intervalDays: 30, lastSaved: now).save('a');
    expect((await BackupPreferences.read('a')).lastSaved, now);
    expect((await BackupPreferences.read('b')).lastSaved, isNull);
  });
  Future<void> pump(WidgetTester tester,
      {bool child = false,
      bool allowed = true,
      FakeGateway? gateway,
      BackupFileSaver? saver}) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          if (saver != null) backupFileSaverProvider.overrideWithValue(saver),
          backupGatewayProvider.overrideWithValue(gateway ?? FakeGateway()),
          canExportDataProvider.overrideWith((ref) async => allowed),
          activeStudentProvider
              .overrideWith((ref) => child ? {'id': 'child'} : null),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: MediaQuery(
                    data:
                        const MediaQueryData(textScaler: TextScaler.linear(2)),
                    child: const SingleChildScrollView(
                        child: Padding(
                            padding: EdgeInsets.all(20),
                            child: BackupSettings())))))));
    await tester.pumpAndSettle();
  }

  testWidgets('hidden in child mode and for accounts without adult scope',
      (tester) async {
    await pump(tester, child: true);
    expect(find.text('Download my data'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await pump(tester, allowed: false);
    expect(find.text('Download my data'), findsNothing);
  });
  testWidgets(
      'narrow large-text UI; preparing and failing never mark a backup saved',
      (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = FakeGateway();
    await pump(tester, gateway: gateway);
    await tester.ensureVisible(find.text('Download my data'));
    await tester.tap(find.text('Download my data'));
    await tester.pumpAndSettle();
    expect(find.text('Save ZIP'), findsOneWidget);
    expect((await BackupPreferences.read('fictional')).lastSaved, isNull);
    expect(tester.takeException(), isNull);
    gateway.fail = true;
    await tester.ensureVisible(find.text('Download my data'));
    await tester.tap(find.text('Download my data'));
    await tester.pumpAndSettle();
    expect(find.text('Missing file. No partial backup was saved.'),
        findsOneWidget);
    expect(find.text('Save ZIP'), findsNothing);
    expect((await BackupPreferences.read('fictional')).lastSaved, isNull);
  });
  testWidgets(
      'cancelled or failed saves do not count; only confirmation records a backup',
      (tester) async {
    var mode = 'cancel';
    await pump(tester, saver: (bytes, filename) async {
      expect(filename, startsWith('JamJot-backup-'));
      if (mode == 'fail') throw Exception('disk unavailable');
      return mode == 'save';
    });
    await tester.ensureVisible(find.text('Download my data'));
    await tester.tap(find.text('Download my data'));
    await tester.pumpAndSettle();
    Future<void> save() async {
      await tester.ensureVisible(find.text('Save ZIP'));
      await tester.tap(find.text('Save ZIP'));
      await tester.pumpAndSettle();
    }

    await save();
    expect(find.text('I saved the ZIP'), findsNothing);
    expect((await BackupPreferences.read('fictional')).lastSaved, isNull);
    mode = 'save';
    await save();
    expect(find.text('I saved the ZIP'), findsOneWidget);
    expect((await BackupPreferences.read('fictional')).lastSaved, isNull);
    mode = 'fail';
    await save();
    expect(find.text('I saved the ZIP'), findsNothing);
    expect((await BackupPreferences.read('fictional')).lastSaved, isNull);
    mode = 'save';
    await save();
    await tester.ensureVisible(find.text('I saved the ZIP'));
    await tester.tap(find.text('I saved the ZIP'));
    await tester.pumpAndSettle();
    expect((await BackupPreferences.read('fictional')).lastSaved, isNotNull);
    expect(find.text('Save ZIP'), findsNothing);
  });
  testWidgets('reminder dismiss snoozes without claiming a successful backup',
      (tester) async {
    await const BackupPreferences(intervalDays: 7).save('fictional');
    await tester.pumpWidget(ProviderScope(
        overrides: [
          backupGatewayProvider.overrideWithValue(FakeGateway()),
          canExportDataProvider.overrideWith((ref) async => true)
        ],
        child: MaterialApp(
            home: Scaffold(body: BackupReminder(onDownload: () {})))));
    await tester.pumpAndSettle();
    expect(find.text('Download my data'), findsOneWidget);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Download my data'), findsNothing);
    final prefs = await BackupPreferences.read('fictional');
    expect(prefs.lastSaved, isNull);
    expect(prefs.dismissedUntil, isNotNull);
  });
}
