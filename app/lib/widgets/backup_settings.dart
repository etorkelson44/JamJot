import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/backup_file.dart';
import '../services/backup_service.dart';
import '../state/app_state.dart';

typedef BackupFileSaver = Future<bool> Function(
    Uint8List bytes, String filename);
final backupFileSaverProvider =
    Provider<BackupFileSaver>((ref) => saveBackupFile);

class BackupSettings extends ConsumerStatefulWidget {
  const BackupSettings({super.key});
  @override
  ConsumerState<BackupSettings> createState() => _BackupSettingsState();
}

class _BackupSettingsState extends ConsumerState<BackupSettings> {
  bool _busy = false, _downloadRequested = false;
  Uint8List? _zip;
  String? _message, _preparedFor;

  Future<void> _prepare() async {
    final gateway = ref.read(backupGatewayProvider);
    final account = gateway.accountId;
    if (account == null || ref.read(activeStudentProvider) != null) return;
    final password = gateway.isPreview
        ? ''
        : await showDialog<String>(
            context: context, builder: (_) => const _VerifyBackupDialog());
    if (password == null || !mounted) return;
    setState(() {
      _busy = true;
      _message = 'Preparing your complete backup…';
      _zip = null;
      _downloadRequested = false;
    });
    try {
      final bytes = await gateway.download(password);
      if (!mounted ||
          gateway.accountId != account ||
          ref.read(activeStudentProvider) != null) {
        return;
      }
      setState(() {
        _zip = bytes;
        _preparedFor = account;
        _message =
            'Your ZIP is ready. Choose Save ZIP to keep it on your device.';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_zip == null ||
        _preparedFor != ref.read(backupGatewayProvider).accountId ||
        ref.read(activeStudentProvider) != null) {
      return;
    }
    setState(() {
      _busy = true;
      _downloadRequested = false;
    });
    try {
      final requested = await ref.read(backupFileSaverProvider)(_zip!,
          'JamJot-backup-${DateFormat('yyyy-MM-dd-HHmmss').format(DateTime.now())}.zip');
      if (!mounted) return;
      setState(() {
        _downloadRequested = requested;
        _message = requested
            ? 'Check that the ZIP is saved and opens, then confirm below. Your reminder updates only after you confirm.'
            : 'Save cancelled. Your last-backup date has not changed.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'The ZIP could not be saved. Please try Save ZIP again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(String account, BackupPreferences prefs) async {
    if (!_downloadRequested ||
        account != _preparedFor ||
        account != ref.read(backupGatewayProvider).accountId ||
        ref.read(activeStudentProvider) != null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await BackupPreferences(
              intervalDays: prefs.intervalDays, lastSaved: DateTime.now())
          .save(account);
      ref.invalidate(backupPreferencesProvider(account));
      if (mounted) {
        setState(() {
          _zip = null;
          _downloadRequested = false;
          _message =
              'Backup saved. Your reminder date is up to date on this device.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'The file may be saved, but the reminder date could not be updated. Please try confirming again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(activeStudentProvider) != null ||
        ref.watch(canExportDataProvider).valueOrNull != true) {
      return const SizedBox.shrink();
    }
    final gateway = ref.watch(backupGatewayProvider);
    final account = gateway.accountId;
    if (account == null) return const SizedBox.shrink();
    final preferences = ref.watch(backupPreferencesProvider(account));
    final prefs = preferences.valueOrNull;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your data',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
            gateway.isPreview
                ? 'Local preview • fictional data only'
                : 'A free, complete copy you can keep.',
            style: text.bodyMedium),
        const SizedBox(height: 6),
        const Text(
            'Includes the student, lesson and practice information you can access, rewards, recordings and authorized documents and messages. Each ZIP opens without JamJot. Shared documents without file-download permission are listed without their files.'),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: _busy ? null : _prepare,
              icon: const Icon(Icons.download_outlined),
              label: Text(_busy ? 'Working…' : 'Download my data')),
          if (_zip != null)
            OutlinedButton(
                onPressed: _busy ? null : _save, child: const Text('Save ZIP')),
          if (_downloadRequested && prefs != null)
            OutlinedButton(
                onPressed: _busy ? null : () => _confirm(account, prefs),
                child: const Text('I saved the ZIP')),
        ]),
        if (_message != null)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Semantics(liveRegion: true, child: Text(_message!))),
        const SizedBox(height: 10),
        Text(
            prefs?.lastSaved == null
                ? 'No saved backup confirmed on this device.'
                : 'Last confirmed backup: ${DateFormat.yMMMd().add_jm().format(prefs!.lastSaved!.toLocal())}',
            style: text.bodySmall),
        const SizedBox(height: 18),
        Text('Backup reminders · design preview', style: text.titleSmall),
        const SizedBox(height: 6),
        const Text(
            'Optional reminders appear before a child profile is selected. These settings apply only to this account on this device.'),
        const SizedBox(height: 10),
        if (prefs != null)
          DropdownButtonFormField<int>(
            initialValue: prefs.intervalDays,
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Remind me to back up'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Off')),
              DropdownMenuItem(value: 7, child: Text('Every week')),
              DropdownMenuItem(value: 30, child: Text('Every 30 days')),
              DropdownMenuItem(value: 90, child: Text('Every 90 days')),
            ],
            onChanged: _busy
                ? null
                : (days) async {
                    if (days == null) return;
                    try {
                      await BackupPreferences(
                              intervalDays: days, lastSaved: prefs.lastSaved)
                          .save(account);
                      ref.invalidate(backupPreferencesProvider(account));
                    } catch (_) {
                      if (mounted) {
                        setState(() => _message =
                            'Could not save the reminder choice. Please try again.');
                      }
                    }
                  },
          ),
        if (preferences.hasError)
          const Text('Reminder settings could not be loaded.'),
        const SizedBox(height: 8),
        const Text(
            'Weekly, 30-day and 90-day choices are a proposal for review. Reminders start off. Dismiss snoozes for one day; it never counts as a backup.'),
      ]),
    );
  }
}

class BackupReminder extends ConsumerWidget {
  const BackupReminder({super.key, required this.onDownload});
  final VoidCallback onDownload;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(activeStudentProvider) != null ||
        ref.watch(canExportDataProvider).valueOrNull != true) {
      return const SizedBox.shrink();
    }
    final account = ref.watch(backupGatewayProvider).accountId;
    if (account == null) return const SizedBox.shrink();
    final prefs = ref.watch(backupPreferencesProvider(account)).valueOrNull;
    if (prefs == null || !prefs.due(DateTime.now())) {
      return const SizedBox.shrink();
    }
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('A little peace of mind',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              const Text(
                  'It may be time to save a fresh copy of your JamJot data.'),
              const SizedBox(height: 8),
              Wrap(spacing: 12, runSpacing: 8, children: [
                FilledButton(
                    onPressed: onDownload,
                    child: const Text('Download my data')),
                TextButton(
                    onPressed: () async {
                      try {
                        await BackupPreferences(
                                intervalDays: prefs.intervalDays,
                                lastSaved: prefs.lastSaved,
                                dismissedUntil:
                                    DateTime.now().add(const Duration(days: 1)))
                            .save(account);
                        ref.invalidate(backupPreferencesProvider(account));
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Could not dismiss the reminder. Please try again.')));
                        }
                      }
                    },
                    child: const Text('Dismiss')),
              ]),
            ])));
  }
}

class _VerifyBackupDialog extends StatefulWidget {
  const _VerifyBackupDialog();
  @override
  State<_VerifyBackupDialog> createState() => _VerifyBackupDialogState();
}

class _VerifyBackupDialogState extends State<_VerifyBackupDialog> {
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) Navigator.pop(context, _password.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Verify your adult account'),
        content: SingleChildScrollView(
            child: Form(
                key: _form,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'Enter your account password to download private data and recordings. This is your sign-in password, not your profile PIN.'),
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: _password,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                              labelText: 'Account password'),
                          autofocus: true,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter your account password.'
                              : null,
                          onFieldSubmitted: (_) => _submit()),
                    ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: const Text('Prepare backup'))
        ],
      );
}
