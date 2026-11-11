import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/pin_dialog.dart' show askForNewPin;
import '../../widgets/backup_settings.dart';
import '../../widgets/ask_maestro.dart' show TisdaleImprint;

/// My guardianship rows (with each kid's name).
final myGuardianRowsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null) return [];
  final rows = await JamJotBackend.client
      .from('guardianships')
      .select('*, students(id, display_name)')
      .eq('profile_id', uid);
  return rows.cast<Map<String, dynamic>>();
});

/// All the places this account is signed in right now.
final mySessionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await JamJotBackend.client.functions
      .invoke('manage-sessions', body: {'action': 'list'});
  final data = res.data as Map<String, dynamic>? ?? {};
  return ((data['sessions'] as List?) ?? []).cast<Map<String, dynamic>>();
});

/// Turns a browser's technical self-description into plain words.
String describeUserAgent(String? ua) {
  if (ua == null || ua.isEmpty) return 'Unknown device';
  String device;
  if (ua.contains('iPhone')) {
    device = 'iPhone';
  } else if (ua.contains('iPad')) {
    device = 'iPad';
  } else if (ua.contains('Android')) {
    device = 'Android';
  } else if (ua.contains('Mac OS') || ua.contains('Macintosh')) {
    device = 'Mac';
  } else if (ua.contains('Windows')) {
    device = 'Windows PC';
  } else if (ua.contains('Linux')) {
    device = 'Linux';
  } else {
    device = 'Device';
  }
  String browser;
  if (ua.contains('Edg/')) {
    browser = 'Edge';
  } else if (ua.contains('OPR/') || ua.contains('Opera')) {
    browser = 'Opera';
  } else if (ua.contains('Chrome/') && !ua.contains('Chromium')) {
    browser = 'Chrome';
  } else if (ua.contains('Firefox/')) {
    browser = 'Firefox';
  } else if (ua.contains('Safari/')) {
    browser = 'Safari';
  } else {
    browser = 'Browser';
  }
  return '$browser on $device';
}

/// Account settings: who I am, how I sign in, and where I stand with each kid.
class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final Map<String, TextEditingController> _shownAs = {};
  final Map<String, TextEditingController> _relation = {};
  bool _loadedBasics = false;
  bool _busy = false;

  static const _grantLabels = {
    'can_message': 'Teacher chats',
    'can_view_calendar': 'Calendar',
    'can_stock_rewards': 'Stocking rewards',
    'can_adjust_practice': 'Adjusting practice',
    'can_pay': 'Payments',
  };

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    for (final c in _shownAs.values) {
      c.dispose();
    }
    for (final c in _relation.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(List<Map<String, dynamic>> rows) async {
    // "Known to (student) as" is required (JJ-054-C).
    for (final r in rows) {
      final id = r['id'] as String;
      if ((_shownAs[id]?.text.trim() ?? '').isEmpty) {
        final kid =
            (r['students'] as Map?)?['display_name'] as String? ?? 'your student';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Please fill in how $kid knows you (Known to $kid as).')));
        return;
      }
    }
    setState(() => _busy = true);
    try {
      final uid = JamJotBackend.client.auth.currentUser!.id;
      final fullName =
          '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
      await JamJotBackend.client.from('profiles').update({
        'full_name': fullName,
        'phone': _phone.text.trim(),
      }).eq('id', uid);
      for (final r in rows) {
        final id = r['id'] as String;
        await JamJotBackend.client.from('guardianships').update({
          'display_name': _shownAs[id]?.text.trim() ?? '',
          'relationship': _relation[id]?.text.trim() ?? '',
        }).eq('id', id);
      }
      ref.invalidate(myProfileProvider);
      ref.invalidate(myGuardianRowsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved! ✨')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save just now — try again?')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeMyPin() async {
    final pin = await askForNewPin(context, title: 'My new grown-up PIN');
    if (pin == null) return;
    try {
      final uid = JamJotBackend.client.auth.currentUser!.id;
      await JamJotBackend.client
          .from('profiles')
          .update({'app_pin_hash': hashPin(pin)}).eq('id', uid);
      ref.invalidate(myProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('PIN updated!')));
      }
    } catch (_) {}
  }

  Future<void> _changePassword() async {
    final pass = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
            side: JamJotShape.border,
          ),
          title: const Text('Change password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pass,
                obscureText: true,
                autofocus: true,
                decoration:
                    const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Type it again to be sure'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!,
                      style:
                          const TextStyle(color: JamJotColors.recording)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (pass.text.length < 8) {
                  setState(() => error = 'At least 8 characters, please.');
                  return;
                }
                if (pass.text != confirm.text) {
                  setState(() => error = 'Those two do not match.');
                  return;
                }
                try {
                  await JamJotBackend.client.auth
                      .updateUser(UserAttributes(password: pass.text));
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Password changed!')));
                  }
                } catch (_) {
                  setState(() =>
                      error = 'Could not change it just now. Try again?');
                }
              },
              style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendResetEmail(String email) async {
    try {
      await JamJotBackend.client.auth.resetPasswordForEmail(email,
          redirectTo: 'https://jamjot.app/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Reset link sent — check your email to pick a new password.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not send the reset email just now.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final rows = ref.watch(myGuardianRowsProvider).valueOrNull ?? [];
    final text = Theme.of(context).textTheme;
    final email = JamJotBackend.client.auth.currentUser?.email ?? '';

    if (profile != null && !_loadedBasics) {
      _loadedBasics = true;
      final parts =
          ((profile['full_name'] as String?) ?? '').trim().split(' ');
      _firstName.text = parts.isNotEmpty ? parts.first : '';
      _lastName.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      _phone.text = (profile['phone'] as String?) ?? '';
    }
    for (final r in rows) {
      final id = r['id'] as String;
      _shownAs.putIfAbsent(id,
          () => TextEditingController(text: r['display_name'] as String? ?? ''));
      _relation.putIfAbsent(id,
          () => TextEditingController(text: r['relationship'] as String? ?? ''));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account settings'),
        leading: BackButton(onPressed: () => context.go('/home')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('About me',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _firstName,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(labelText: 'First name'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lastName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
            const SizedBox(height: 18),
            const BackupSettings(),
            Text('Sign-in & security',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Email: $email',
                style: text.bodyMedium),
            Text('(Changing your sign-in email is coming in a later update.)',
                style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _changePassword,
                  child: const Text('Change password'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _sendResetEmail(email),
                  child: const Text('Email me a reset link'),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            Text('Where I\'m signed in',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Every browser and device where this account is active. Sign out of any you don\'t recognize (it takes effect within the hour).',
              style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
            ),
            const SizedBox(height: 8),
            Consumer(builder: (context, ref, _) {
              final sessionsAsync = ref.watch(mySessionsProvider);
              final sessions = sessionsAsync.valueOrNull;
              if (sessions == null) {
                return sessionsAsync.hasError
                    ? Text('Could not load sign-ins right now.',
                        style: text.bodySmall
                            ?.copyWith(color: JamJotColors.inkSoft))
                    : const Padding(
                        padding: EdgeInsets.all(8),
                        child: Center(
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))),
                      );
              }
              return Column(children: [
                for (final s in sessions) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: s['current'] == true
                              ? JamJotColors.blueberry
                              : JamJotColors.ink,
                          width: 2),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: Text(
                                  describeUserAgent(
                                      s['user_agent'] as String?),
                                  style: text.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (s['current'] == true)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Text('• this device',
                                      style: TextStyle(
                                          color: JamJotColors.blueberry,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)),
                                ),
                            ]),
                            Text(
                              '${(s['ip'] as String?) ?? 'unknown network'} • last active ${DateFormat('MMM d, h:mm a').format(DateTime.parse(s['last_active'] as String).toLocal())}',
                              style: text.bodySmall
                                  ?.copyWith(color: JamJotColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      if (s['current'] != true)
                        TextButton(
                          onPressed: () async {
                            try {
                              await JamJotBackend.client.functions.invoke(
                                  'manage-sessions',
                                  body: {
                                    'action': 'revoke',
                                    'session_id': s['id'],
                                  });
                              ref.invalidate(mySessionsProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Signed out of that device.')));
                              }
                            } catch (_) {}
                          },
                          child: const Text('Sign out',
                              style: TextStyle(
                                  color: JamJotColors.recording)),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  // The maker's mark, kept quiet.
                  const Center(
                      child: TisdaleImprint(height: 40, opacity: 0.18)),
                  const SizedBox(height: 8),
                ],
              ]);
            }),
            const SizedBox(height: 18),
            Text('My grown-up PIN',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'The 4-digit code that guards your profile from the kids. Forgot it? No problem — you\'re signed in with your password, so just set a new one here.',
              style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _changeMyPin,
              child: Text(
                  (profile?['app_pin_hash'] != null)
                      ? 'Change my PIN'
                      : 'Set my PIN'),
            ),
            const SizedBox(height: 22),
            if (rows.isNotEmpty) ...[
              Text('My kids',
                  style:
                      text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final r in rows) ...[
                _kidCard(context, r, text),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : () => _save(rows),
              child: Text(_busy ? 'Saving…' : 'Save my settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kidCard(
      BuildContext context, Map<String, dynamic> r, TextTheme text) {
    final kidName =
        (r['students'] as Map?)?['display_name'] as String? ?? 'Student';
    final studentId = (r['students'] as Map?)?['id'] as String?;
    final isPrimary = r['is_primary'] == true;
    final granted = [
      for (final e in _grantLabels.entries)
        if (r[e.key] == true) e.value,
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
        border: Border.all(color: JamJotColors.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text('🎵 $kidName',
                  style:
                      text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (isPrimary)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: JamJotColors.marigoldTint,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: JamJotColors.ink, width: 1),
                ),
                child: const Text('Primary caregiver',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _shownAs[r['id']],
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
                labelText: 'Known to $kidName as',
                helperText:
                    'What $kidName calls you, like Dad, Grandma Jo or Auntie Em. Required.',
                helperMaxLines: 2),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _relation[r['id']],
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Relationship (e.g. Grandma)'),
          ),
          if (!isPrimary) ...[
            const SizedBox(height: 10),
            if (studentId != null)
              Consumer(builder: (context, ref, _) {
                final all = ref
                        .watch(kidGuardianshipsProvider(studentId))
                        .valueOrNull ??
                    [];
                final primary = all
                    .where((g) => g['is_primary'] == true)
                    .firstOrNull;
                final primaryName =
                    ((primary?['display_name'] as String?) ?? '')
                        .trim()
                        .split(' ')
                        .first;
                return Text(
                  'Primary caregiver: ${primaryName.isEmpty ? '(not named yet)' : primaryName}',
                  style: text.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                );
              }),
            const SizedBox(height: 4),
            Text(
              granted.isEmpty
                  ? 'Your permissions: following along with practice.'
                  : 'Your permissions: ${granted.join(' • ')}',
              style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
            ),
            if (r['grants_updated_at'] != null)
              Text(
                'Last changed ${DateFormat('MMM d, h:mm a').format(DateTime.parse(r['grants_updated_at'] as String).toLocal())}',
                style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
              ),
          ],
        ],
      ),
    );
  }
}

/// Shows a one-time banner when the primary changes this person's
/// permissions. Returns widgets to put at the top of the home screen.
class PermissionChangeNotices extends ConsumerStatefulWidget {
  const PermissionChangeNotices({super.key});

  @override
  ConsumerState<PermissionChangeNotices> createState() =>
      _PermissionChangeNoticesState();
}

class _PermissionChangeNoticesState
    extends ConsumerState<PermissionChangeNotices> {
  final Set<String> _dismissed = {};

  Future<void> _markSeen(String gid, String stamp) async {
    setState(() => _dismissed.add(gid));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('grants_seen_$gid', stamp);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(myGuardianRowsProvider).valueOrNull ?? [];
    final text = Theme.of(context).textTheme;
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snap) {
        final prefs = snap.data;
        if (prefs == null) return const SizedBox.shrink();
        final notices = <Widget>[];
        for (final r in rows) {
          if (r['is_primary'] == true) continue;
          final stamp = r['grants_updated_at'] as String?;
          if (stamp == null) continue;
          final gid = r['id'] as String;
          if (_dismissed.contains(gid)) continue;
          final seen = prefs.getString('grants_seen_$gid');
          if (seen == stamp) continue;
          final kidName =
              (r['students'] as Map?)?['display_name'] ?? 'your musician';
          notices.add(Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JamJotColors.marigoldTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: JamJotColors.ink, width: 2),
            ),
            child: Row(children: [
              const Text('🔔', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your permissions for $kidName were updated — see Account settings for the current list.',
                  style:
                      text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => _markSeen(gid, stamp),
              ),
            ]),
          ));
        }
        if (notices.isEmpty) return const SizedBox.shrink();
        return Column(children: notices);
      },
    );
  }
}
