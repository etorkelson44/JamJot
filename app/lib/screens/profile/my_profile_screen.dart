import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';

/// My own grown-up details: name, phone, and how I'm shown for each kid.
final myGuardianRowsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null) return [];
  final rows = await JamJotBackend.client
      .from('guardianships')
      .select('*, students(display_name)')
      .eq('profile_id', uid);
  return rows.cast<Map<String, dynamic>>();
});

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final Map<String, TextEditingController> _shownAs = {};
  final Map<String, TextEditingController> _relation = {};
  bool _loadedBasics = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
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
    setState(() => _busy = true);
    try {
      final uid = JamJotBackend.client.auth.currentUser!.id;
      await JamJotBackend.client.from('profiles').update({
        'full_name': _name.text.trim(),
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
            const SnackBar(content: Text('Saved! Looking good. ✨')));
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

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final rows = ref.watch(myGuardianRowsProvider).valueOrNull ?? [];
    final text = Theme.of(context).textTheme;
    final email = JamJotBackend.client.auth.currentUser?.email ?? '';

    if (profile != null && !_loadedBasics) {
      _loadedBasics = true;
      _name.text = (profile['full_name'] as String?) ?? '';
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
        title: const Text('My profile'),
        leading: BackButton(onPressed: () => context.go('/home')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'My name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'My phone number'),
            ),
            const SizedBox(height: 12),
            Text('Sign-in email: $email',
                style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
            Text('(Changing your sign-in email is coming in a later update.)',
                style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
            const SizedBox(height: 20),
            if (rows.isNotEmpty) ...[
              Text('How I\'m shown for each kid',
                  style:
                      text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final r in rows) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(JamJotShape.cardRadius),
                    border: Border.all(color: JamJotColors.ink, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '🎵 ${(r['students'] as Map?)?['display_name'] ?? 'Student'}',
                          style: text.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _shownAs[r['id']],
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            labelText: 'Shown as (e.g. Grandma Jo)'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _relation[r['id']],
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            labelText: 'Relationship (e.g. Grandma)'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : () => _save(rows),
              child: Text(_busy ? 'Saving…' : 'Save my profile'),
            ),
          ],
        ),
      ),
    );
  }
}
