import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../services/supabase_service.dart';
import '../state/albums.dart';
import '../state/app_state.dart';
import '../theme/jamjot_theme.dart';
import 'alien_fans.dart';
import 'notestar_art.dart';

/// Grown-up controls for a kid's Superfans (NoteStar, 2026-11-15):
/// family members who may receive the kid's weekly albums, the
/// "read fan mail first" switch (on by default), and fan mail to approve.
class SuperfansPanel extends ConsumerStatefulWidget {
  const SuperfansPanel({super.key, required this.kid});
  final Map<String, dynamic> kid;
  @override
  ConsumerState<SuperfansPanel> createState() => _SuperfansPanelState();
}

class _SuperfansPanelState extends ConsumerState<SuperfansPanel> {
  bool? _review;
  String get _sid => widget.kid['id'] as String;

  Future<void> _add() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a Superfan'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              decoration:
                  const InputDecoration(labelText: 'Name (e.g. Grandma Jo)')),
          const SizedBox(height: 8),
          TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    final n = name.text.trim(), e = email.text.trim();
    if (n.isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please enter a name and a real email address.')));
      }
      return;
    }
    try {
      await JamJotBackend.client
          .from('fans')
          .insert({'student_id': _sid, 'name': n, 'email': e});
      ref.invalidate(superfansProvider(_sid));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Only caregivers can add Superfans.')));
      }
    }
  }

  Future<void> _remove(Map<String, dynamic> f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${f['name']}?'),
        content: const Text('Album links already sent to them stop working.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await JamJotBackend.client
        .from('fans')
        .delete()
        .eq('id', f['id'] as String);
    ref.invalidate(superfansProvider(_sid));
  }

  Future<void> _setReview(bool v) async {
    setState(() => _review = v);
    try {
      await JamJotBackend.client
          .from('students')
          .update({'fan_mail_review': v}).eq('id', _sid);
      ref.invalidate(myStudentsProvider);
    } catch (_) {
      setState(() => _review = !v);
    }
  }

  Future<void> _mark(Map<String, dynamic> m, String status) async {
    await JamJotBackend.client.from('fan_mail').update({
      'status': status,
      'reviewed_by': JamJotBackend.client.auth.currentUser?.id,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', m['id'] as String);
    ref.invalidate(fanMailProvider(_sid));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = (widget.kid['display_name'] as String).split(' ').first;
    final fans = ref.watch(superfansProvider(_sid)).valueOrNull ?? [];
    final mail = ref.watch(fanMailProvider(_sid)).valueOrNull ?? [];
    final pending = mail.where((m) => m['status'] == 'pending').toList();
    final review = _review ?? (widget.kid['fan_mail_review'] as bool? ?? true);
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Center(child: AlienCrowd(width: 240, cheering: false)),
      const SizedBox(height: 8),
      Row(children: [
        const PaperAccent('star_big_pink', size: 32),
        const SizedBox(width: 10),
        Expanded(child: Text("$name's Superfans", style: text.titleLarge)),
      ]),
      const SizedBox(height: 4),
      Text(
          '$name can send their weekly albums to these people. They get a private link to listen and send fan mail. '
          'Fans (the number on $name\'s Home) grow on their own as $name finishes songs and practices.',
          style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft)),
      const SizedBox(height: 12),
      for (final f in fans)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const PaperAccent('dot_pink', size: 26),
          title: Text(f['name'] as String),
          subtitle: Text(f['email'] as String),
          trailing: IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close),
              onPressed: () => _remove(f)),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Add a Superfan')),
      ),
      const Divider(height: 32),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: review,
        onChanged: _setReview,
        title: const Text('Let me read fan mail first'),
        subtitle: Text(
            'Notes wait here until you approve them, then $name sees them.'),
      ),
      if (pending.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Waiting for you', style: text.titleMedium),
        for (final m in pending)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'From ${m['fan_name']} · ${DateFormat.MMMd().format(DateTime.parse(m['created_at'] as String).toLocal())}',
                        style: text.titleSmall),
                    const SizedBox(height: 4),
                    Text(m['message'] as String),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(
                          onPressed: () => _mark(m, 'hidden'),
                          child: const Text('Hide')),
                      const SizedBox(width: 8),
                      FilledButton(
                          onPressed: () => _mark(m, 'approved'),
                          child: Text('Show $name')),
                    ]),
                  ]),
            ),
          ),
      ],
      const Divider(height: 32),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const PaperAccent('star_big_blue', size: 30),
        title: Text("$name's albums and fan mail"),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/recordings?student=$_sid'),
      ),
    ]);
  }
}
