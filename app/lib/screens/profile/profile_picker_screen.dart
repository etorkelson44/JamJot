import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/pin_dialog.dart';

class ProfilePickerScreen extends ConsumerWidget {
  const ProfilePickerScreen({super.key});

  Future<void> _pickGrownUp(
      BuildContext context, WidgetRef ref, Map<String, dynamic>? profile) async {
    final active = ref.read(activeStudentProvider);
    final pinHash = profile?['app_pin_hash'] as String?;
    // Leaving a kid profile ALWAYS requires the grown-up PIN.
    if (active != null) {
      if (pinHash != null) {
        final ok = await askForPin(context,
            title: 'Grown-up PIN', pinHash: pinHash);
        if (!ok) return;
      }
      // Legacy account without a PIN: let them through once, then make
      // them set one right away so the door locks behind them.
      ref.read(activeStudentProvider.notifier).state = null;
      await rememberActiveStudent(null);
      if (context.mounted && pinHash == null) {
        await _setGrownUpPin(context, ref, required: true);
      }
      if (context.mounted) context.go('/home');
      return;
    }
    ref.read(activeStudentProvider.notifier).state = null;
    await rememberActiveStudent(null);
    if (context.mounted) context.go('/home');
  }

  Future<void> _pickKid(BuildContext context, WidgetRef ref,
      Map<String, dynamic> kid, Map<String, dynamic>? profile) async {
    final active = ref.read(activeStudentProvider);
    final kidPinHash = kid['pin_hash'] as String?;
    final grownUpPinHash = profile?['app_pin_hash'] as String?;
    if (active == null) {
      // Grown-up entering a kid profile: free — but only once the
      // grown-up PIN exists, so kids can never wander back out.
      if (grownUpPinHash == null) {
        final set = await _setGrownUpPin(context, ref, required: true);
        if (!set || !context.mounted) return;
      }
    } else if (active['id'] != kid['id']) {
      // Sibling switch: the target kid's PIN opens their profile —
      // or the grown-up PIN when that kid has none.
      if (kidPinHash != null) {
        final ok = await askForPin(context,
            title: "${kid['display_name']}'s PIN", pinHash: kidPinHash);
        if (!ok) return;
      } else if (grownUpPinHash != null) {
        final ok = await askForPin(context,
            title: 'Grown-up PIN', pinHash: grownUpPinHash);
        if (!ok) return;
      }
    }
    if (!context.mounted) return;
    ref.read(activeStudentProvider.notifier).state = kid;
    await rememberActiveStudent(kid['id'] as String);
    if (context.mounted) context.go('/home');
  }

  Future<bool> _setGrownUpPin(BuildContext context, WidgetRef ref,
      {bool required = false}) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: !required,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text(required
            ? 'First, set your grown-up PIN'
            : 'Set your grown-up PIN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration:
              const InputDecoration(counterText: '', hintText: '4 digits'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (pin == null || pin.length != 4) return false;
    final uid = JamJotBackend.client.auth.currentUser!.id;
    await JamJotBackend.client
        .from('profiles')
        .update({'app_pin_hash': hashPin(pin)}).eq('id', uid);
    ref.invalidate(myProfileProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN saved. Kids now need it to reach your profile.')),
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final studentsAsync = ref.watch(myStudentsProvider);
    final active = ref.watch(activeStudentProvider);
    final text = Theme.of(context).textTheme;

    final profile = profileAsync.valueOrNull;
    final students = studentsAsync.valueOrNull ?? [];
    final grownUpName = (profile?['full_name'] as String?)?.trim();
    final kidIsActive = active != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Who is playing?'),
        automaticallyImplyLeading: false,
        actions: [
          if (!kidIsActive) ...[
            IconButton(
              tooltip: 'Set grown-up PIN',
              icon: const Icon(Icons.lock_outline),
              onPressed: () => _setGrownUpPin(context, ref),
            ),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await JamJotBackend.client.auth.signOut();
                ref.read(activeStudentProvider.notifier).state = null;
                if (context.mounted) context.go('/');
              },
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _ProfileTile(
                    emoji: '🧑',
                    label: (grownUpName == null || grownUpName.isEmpty)
                        ? 'Grown-up'
                        : grownUpName.split(' ').first,
                    tint: JamJotColors.blueberryTint,
                    locked: kidIsActive && profile?['app_pin_hash'] != null,
                    onTap: () => _pickGrownUp(context, ref, profile),
                  ),
                  for (final kid in students)
                    _ProfileTile(
                      emoji: '🎵',
                      label: kid['display_name'] as String,
                      tint: JamJotColors.marigoldTint,
                      locked: kidIsActive &&
                          active['id'] != kid['id'] &&
                          kid['pin_hash'] != null,
                      onTap: () => _pickKid(context, ref, kid, profile),
                    ),
                  if (!kidIsActive)
                    _ProfileTile(
                      emoji: '➕',
                      label: 'Add a kid',
                      tint: JamJotColors.plumTint,
                      onTap: () => context.go('/add-student'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Grown-ups can hop into kid profiles freely. Getting back out asks for a PIN.',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.emoji,
    required this.label,
    required this.tint,
    required this.onTap,
    this.locked = false,
  });

  final String emoji;
  final String label;
  final Color tint;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 140,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                    border: Border.all(color: JamJotColors.ink, width: 2),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style:
                      text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (locked)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.lock_outline,
                        size: 16, color: JamJotColors.inkSoft),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
