// Local review entrypoint. No real accounts, network data, or production writes.
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jamjot/screens/profile/my_profile_screen.dart';
import 'package:jamjot/screens/profile/profile_picker_screen.dart';
import 'package:jamjot/services/backup_service.dart';
import 'package:jamjot/state/app_state.dart';
import 'package:jamjot/theme/jamjot_theme.dart';
import 'backup_fixture.dart';

class FictionalBackup extends BackupGateway {
  @override
  String get accountId => 'fictional-backup-preview-v1';
  @override
  bool get isPreview => true;
  @override
  Future<Uint8List> download(String password) async =>
      base64Decode(fictionalBackupZip);
}

const previewStudent = <String, dynamic>{
  'id': '00000000-0000-4000-8000-000000000011',
  'display_name': 'Melody',
  'instruments': ['piano']
};
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
      url: 'https://jamjot-backup-preview.invalid',
      publishableKey: 'fictional-only',
      authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false, persistSession: false),
      httpClient: MockClient((r) async => http.Response(
          r.method == 'GET'
              ? '[]'
              : '{"message":"Preview only — no account changes"}',
          r.method == 'GET' ? 200 : 403,
          headers: {'content-type': 'application/json'})));
  runApp(ProviderScope(overrides: [
    backupGatewayProvider.overrideWithValue(FictionalBackup()),
    canExportDataProvider.overrideWith((ref) async => true),
    myProfileProvider.overrideWith((ref) async => {
          'id': 'fictional-adult',
          'full_name': 'Fictional Adult',
          'app_pin_hash': hashPin('1234')
        }),
    myStudentsProvider.overrideWith((ref) async => [
          {...previewStudent, 'pin_hash': hashPin('1234')}
        ]),
    myTeacherProvider.overrideWith((ref) async => null),
    myGuardianRowsProvider.overrideWith((ref) async => []),
    mySessionsProvider.overrideWith((ref) async => []),
  ], child: const BackupPreviewApp()));
}

final previewRouter = GoRouter(initialLocation: '/account', routes: [
  ShellRoute(
      builder: (context, state, child) => _PreviewFrame(child: child),
      routes: [
        GoRoute(path: '/account', builder: (_, __) => const MyProfileScreen()),
        GoRoute(
            path: '/profiles', builder: (_, __) => const ProfilePickerScreen()),
        GoRoute(path: '/home', builder: (_, __) => const ProfilePickerScreen()),
      ]),
]);

class BackupPreviewApp extends ConsumerWidget {
  const BackupPreviewApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
      title: 'JamJot • Backup preview',
      theme: buildJamJotTheme(ref.watch(activeStudentProvider) == null
          ? JamJotSkin.grownup
          : JamJotSkin.kid),
      routerConfig: previewRouter);
}

class _PreviewFrame extends ConsumerWidget {
  const _PreviewFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
          body: SafeArea(
              child: Column(children: [
        Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                          'Local backup preview • Fictional data • PIN 1234'),
                      TextButton(
                          onPressed: () {
                            ref.read(activeStudentProvider.notifier).state =
                                null;
                            context.go('/account');
                          },
                          child: const Text('Adult Settings')),
                      TextButton(
                          onPressed: () {
                            ref.read(activeStudentProvider.notifier).state =
                                null;
                            context.go('/profiles');
                          },
                          child: const Text('Account selection')),
                      TextButton(
                          onPressed: () {
                            ref.read(activeStudentProvider.notifier).state =
                                previewStudent;
                            context.go('/account');
                          },
                          child: const Text('Check child mode')),
                    ]))),
        Expanded(child: child),
      ])));
}
