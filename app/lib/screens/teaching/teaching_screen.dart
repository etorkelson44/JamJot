import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/jamjot_card.dart';
import '../library/library_screen.dart' show showCreateLessonDialog;

/// The teacher's home base: invite families, see the roster, teach.
class TeachingScreen extends ConsumerWidget {
  const TeachingScreen({super.key});

  Future<void> _inviteFamily(BuildContext context, WidgetRef ref,
      Map<String, dynamic> teacher) async {
    final name = TextEditingController();
    final instrument = TextEditingController(
        text: (teacher['instruments'] as List?)?.firstOrNull ?? '');
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: const Text('Invite a family'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: "Student's first name (optional)"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: instrument,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Instrument'),
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
              final uid = JamJotBackend.client.auth.currentUser!.id;
              final row = await JamJotBackend.client
                  .from('invitations')
                  .insert({
                    'kind': 'enrollment',
                    'created_by': uid,
                    'teacher_id': teacher['id'],
                    'studio_id': teacher['studio_id'],
                    'instrument': instrument.text.trim().isEmpty
                        ? 'Music'
                        : instrument.text.trim(),
                    'preset_grants': {
                      if (name.text.trim().isNotEmpty)
                        'student_name': name.text.trim(),
                    },
                  })
                  .select()
                  .single();
              if (context.mounted) Navigator.of(context).pop(row);
            },
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            child: const Text('Create invite'),
          ),
        ],
      ),
    );
    if (created == null || !context.mounted) return;
    final link =
        'https://etorkelson44.github.io/JamJot/#/invite?token=${created['token']}';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: const Text('Invite ready! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Send this link to the family any way you like — text, email, carrier pigeon. It works whether or not they have JamJot yet.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: JamJotColors.blueberryTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(link,
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied!')));
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy link'),
            style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
          ),
        ],
      ),
    );
  }

  /// Each teacher has one standing code families can use anytime —
  /// as text, a link, or a QR code at the studio door.
  Future<void> _showMyCode(BuildContext context, WidgetRef ref,
      Map<String, dynamic> teacher) async {
    final uid = JamJotBackend.client.auth.currentUser!.id;
    // Find (or mint) the standing, reusable invitation.
    final existing = await JamJotBackend.client
        .from('invitations')
        .select()
        .eq('created_by', uid)
        .eq('single_use', false)
        .limit(1);
    Map<String, dynamic> invite;
    if (existing.isNotEmpty) {
      invite = existing.first;
    } else {
      invite = await JamJotBackend.client
          .from('invitations')
          .insert({
            'kind': 'enrollment',
            'created_by': uid,
            'teacher_id': teacher['id'],
            'studio_id': teacher['studio_id'],
            'instrument':
                (teacher['instruments'] as List?)?.firstOrNull ?? 'Music',
            'single_use': false,
          })
          .select()
          .single();
    }
    if (!context.mounted) return;
    final code = invite['token'] as String;
    final link = 'https://etorkelson44.github.io/JamJot/#/invite?token=$code';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: const Text('My teacher code'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Families can scan this, tap the link, or type the code into JamJot to connect with you — it never expires and works for every student.'),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: JamJotColors.ink, width: 2),
                ),
                child: QrImageView(
                  data: link,
                  size: 190,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText('Code: $code',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied!')));
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy link'),
            style: FilledButton.styleFrom(minimumSize: const Size(130, 44)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(myTeacherProvider).valueOrNull;
    final roster = ref.watch(teacherStudentsProvider).valueOrNull ?? [];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My teaching'),
        leading: BackButton(onPressed: () => context.go('/home')),
      ),
      body: SafeArea(
        child: teacher == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(teacher['display_name'] as String? ?? '',
                      style: text.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                      (teacher['instruments'] as List?)?.join(' · ') ?? '',
                      style: text.bodyMedium
                          ?.copyWith(color: JamJotColors.inkSoft)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _inviteFamily(context, ref, teacher),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Invite a family'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _showMyCode(context, ref, teacher),
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('My teacher code (QR & link)'),
                  ),
                  const SizedBox(height: 20),
                  Text('My students',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (roster.isEmpty)
                    Text(
                      'No students yet — send your first invite and the family appears here the moment they accept.',
                      style: text.bodyMedium
                          ?.copyWith(color: JamJotColors.inkSoft),
                    )
                  else
                    for (final s in roster) ...[
                      JamJotCard(
                        emoji: '🧒',
                        tint: JamJotColors.blueberryTint,
                        title: s['display_name'] as String,
                        subtitle: s['enrollment_instrument'] as String?,
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => showCreateLessonDialog(
                                context, ref,
                                student: s,
                                enrollmentId:
                                    s['enrollment_id'] as String?),
                            child: const Text('Assign lesson'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.go(
                                '/history?student=${s['id']}&name=${Uri.encodeComponent(s['display_name'] as String)}'),
                            child: const Text('History'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),
                    ],
                ],
              ),
      ),
    );
  }
}
