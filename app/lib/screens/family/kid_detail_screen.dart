import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/jamjot_card.dart';
import '../../widgets/pin_dialog.dart' show askForNewPin;
import '../history/practice_history_screen.dart' show PracticeHistoryList;
import '../library/library_screen.dart' show showCreateLessonDialog;

/// One kid's world in the grown-up view, organized into tabs:
/// Overview • Teachers • Practices • Caregivers.
class KidDetailScreen extends ConsumerWidget {
  const KidDetailScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(myStudentsProvider).valueOrNull ?? [];
    final kid = students.where((s) => s['id'] == studentId).firstOrNull;

    if (kid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final name = kid['display_name'] as String;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name),
          leading: BackButton(onPressed: () => context.go('/home')),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Teachers'),
            Tab(text: 'Practices'),
            Tab(text: 'Caregivers'),
          ]),
        ),
        body: TabBarView(children: [
          _OverviewTab(kid: kid),
          _TeachersTab(kid: kid),
          PracticeHistoryList(studentId: studentId),
          _CaregiversTab(studentId: studentId),
        ]),
      ),
    );
  }
}

// ----------------------------------------------------------------- Overview

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.kid});
  final Map<String, dynamic> kid;

  Widget _statChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: JamJotColors.ink, width: 1.5),
        ),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentId = kid['id'] as String;
    final text = Theme.of(context).textTheme;
    final berries = ref.watch(berryBalanceProvider(studentId)).valueOrNull;
    final fans = ref.watch(fanTotalProvider(studentId)).valueOrNull;
    final progress = ref.watch(weeklyProgressProvider(studentId)).valueOrNull;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: JamJotColors.marigoldTint,
                shape: BoxShape.circle,
                border: Border.all(color: JamJotColors.ink, width: 2),
              ),
              child: const Text('🎵', style: TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kid['display_name'] as String,
                      style: text.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text((kid['instruments'] as List?)?.join(' · ') ?? '',
                      style: text.bodyMedium
                          ?.copyWith(color: JamJotColors.inkSoft)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _statChip('🫐 ${berries ?? '…'} berries'),
            _statChip('🕶️ ${fans ?? '…'} fans'),
            if (progress != null)
              _statChip(
                  '📅 ${progress['days']} day${progress['days'] == 1 ? '' : 's'} this week'),
            if (progress != null)
              _statChip('⏱️ ${progress['today_minutes']} min today'),
          ],
        ),
        const SizedBox(height: 20),
        if (kid['is_primary'] == true)
          JamJotCard(
            emoji: '🔢',
            tint: JamJotColors.blueberryTint,
            title: (kid['pin_hash'] != null)
                ? "Change ${kid['display_name']}'s PIN"
                : "Set ${kid['display_name']}'s PIN",
            subtitle:
                'Their 4-digit code keeps siblings out. Forgot it? Just set a new one here.',
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final pin = await askForNewPin(context,
                  title: "${kid['display_name']}'s new PIN");
              if (pin == null) return;
              try {
                await JamJotBackend.client
                    .from('students')
                    .update({'pin_hash': hashPin(pin)}).eq('id', studentId);
                ref.invalidate(myStudentsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN updated!')));
                }
              } catch (_) {}
            },
          ),
        const SizedBox(height: 12),
        Text(
          'The Teachers tab holds each teacher connection (and your family-run practice) separately; Practices shows every session with recordings; Caregivers manages who helps and what they can do.',
          style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- Teachers

class _TeachersTab extends ConsumerWidget {
  const _TeachersTab({required this.kid});
  final Map<String, dynamic> kid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentId = kid['id'] as String;
    final name = kid['display_name'] as String;
    final enrollments =
        ref.watch(kidEnrollmentsProvider(studentId)).valueOrNull ?? [];
    final chats = ref.watch(myChatsProvider).valueOrNull ?? [];
    final text = Theme.of(context).textTheme;

    Widget header(String label) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(label,
              style:
                  text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final e in enrollments) ...[
          header(
              '🎻 ${(e['teachers'] as Map?)?['display_name'] ?? 'Teacher'} • ${e['instrument']}'),
          _SectionCards(
            kid: kid,
            name: name,
            enrollmentId: e['id'] as String,
            sectionLabel:
                '${(e['teachers'] as Map?)?['display_name'] ?? 'Teacher'} (${e['instrument']})',
            chat: chats
                .where((c) => c['enrollment_id'] == e['id'])
                .firstOrNull,
          ),
          const SizedBox(height: 22),
        ],
        header('🏡 Family-run practice'),
        _SectionCards(
          kid: kid,
          name: name,
          enrollmentId: null,
          sectionLabel: 'Family-run',
          chat: null,
        ),
        if (kid['is_primary'] == true) ...[
          const SizedBox(height: 22),
          header('➕ Connect a new teacher'),
          JamJotCard(
            emoji: '🔗',
            tint: JamJotColors.blueberryTint,
            title: 'I have a teacher code or link',
            subtitle:
                'Type the code from $name\'s teacher (or scan their QR with your camera).',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _enterTeacherCode(context, ref, kid),
          ),
          const SizedBox(height: 10),
          JamJotCard(
            emoji: '✉️',
            tint: JamJotColors.marigoldTint,
            title: 'Invite the teacher to JamJot',
            subtitle:
                'Not on JamJot yet? Send a ready-written email explaining the app.',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _emailTeacherInvite(name),
          ),
        ],
      ],
    );
  }

  Future<void> _enterTeacherCode(
      BuildContext context, WidgetRef ref, Map<String, dynamic> kid) async {
    final code = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
            side: JamJotShape.border,
          ),
          title: const Text('Enter teacher code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: code,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Code (or paste their whole link)'),
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
                var token = code.text.trim();
                // Accept a pasted link too.
                final match = RegExp(r'token=([a-f0-9]+)').firstMatch(token);
                if (match != null) token = match.group(1)!;
                try {
                  final res = await JamJotBackend.client.functions.invoke(
                      'redeem-invite',
                      body: {'token': token, 'student_id': kid['id']});
                  final data = res.data as Map<String, dynamic>? ?? {};
                  if (data['mode'] == 'redeemed') {
                    ref.invalidate(
                        kidEnrollmentsProvider(kid['id'] as String));
                    ref.invalidate(myChatsProvider);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Connected with ${data['teacher_name']}! 🎉')));
                    }
                  } else {
                    setState(() => error =
                        (data['error'] as String?) ?? 'That code did not work.');
                  }
                } catch (_) {
                  setState(() => error = 'That code did not work. Check it and try again?');
                }
              },
              style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _emailTeacherInvite(String kidName) async {
    const appLink = 'https://etorkelson44.github.io/JamJot/';
    final subject = Uri.encodeComponent(
        'Would you try JamJot for $kidName\'s music practice?');
    final body = Uri.encodeComponent('''Hi!

We've started using JamJot, an app that makes $kidName's home practice really count: it listens while they play, so only real playing time is counted, records their practice so you can hear exactly how the week went, and keeps them motivated with little rewards for finishing their assigned songs.

For you as a teacher, it means: you assign the week's songs with your notes, see (and hear!) exactly what was practiced before each lesson, and can message us through the app.

Creating a teacher account is free and takes about two minutes:
1. Open $appLink
2. Tap "I teach music" and set up your profile
3. Open "My teaching" → "My teacher code" and send us the code or QR — we'll connect $kidName right away

Hope you'll give it a try!
''');
    await launchUrl(Uri.parse('mailto:?subject=$subject&body=$body'));
  }
}

class _SectionCards extends ConsumerWidget {
  const _SectionCards({
    required this.kid,
    required this.name,
    required this.enrollmentId,
    required this.sectionLabel,
    required this.chat,
  });

  final Map<String, dynamic> kid;
  final String name;
  final String? enrollmentId;
  final String sectionLabel;
  final Map<String, dynamic>? chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentId = kid['id'] as String;
    final enrollParam = enrollmentId == null
        ? ''
        : '&enrollment=$enrollmentId&section=${Uri.encodeComponent(sectionLabel)}';
    final iAmPrimary = kid['is_primary'] == true;
    return Column(children: [
      if (iAmPrimary) ...[
        JamJotCard(
          emoji: '🎼',
          tint: JamJotColors.blueberryTint,
          title: 'Practice list',
          subtitle: 'Songs, notes, and goals for $sectionLabel.',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(
              '/lesson-builder?student=$studentId&name=${Uri.encodeComponent(name)}$enrollParam'),
        ),
        const SizedBox(height: 10),
        JamJotCard(
          emoji: '🪄',
          tint: JamJotColors.marigoldTint,
          title: 'Assign a lesson',
          subtitle: 'From your library, with goals & a start date.',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showCreateLessonDialog(context, ref,
              student: kid, enrollmentId: enrollmentId),
        ),
      ] else ...[
        JamJotCard(
          emoji: '👀',
          tint: JamJotColors.blueberryTint,
          title: 'Practice & lessons',
          subtitle:
              'Managed by ${enrollmentId == null ? 'the primary caregiver' : 'the teacher'} — follow along in Practices.',
        ),
      ],
      if (chat != null) ...[
        const SizedBox(height: 10),
        JamJotCard(
          emoji: '💬',
          title: 'Chat with ${chat!['teacher_name']}',
          subtitle: chat!['instrument'] as String?,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(
              '/chat?enrollment=${chat!['enrollment_id']}&title=${Uri.encodeComponent('$name × ${chat!['teacher_name']}')}&primary=${chat!['i_am_primary'] == true ? 1 : 0}&teacher=${chat!['teacher_profile_id']}'),
        ),
      ],
      if (enrollmentId != null) ...[
        const SizedBox(height: 10),
        JamJotCard(
          emoji: '🧺',
          tint: JamJotColors.plumTint,
          title: 'Teacher\'s market stand',
          subtitle: 'Rewards this teacher stocks — opens with the Market.',
        ),
      ],
    ]);
  }
}

// --------------------------------------------------------------- Caregivers

class _CaregiversTab extends ConsumerWidget {
  const _CaregiversTab({required this.studentId});
  final String studentId;

  Future<void> _setGrant(BuildContext context, WidgetRef ref,
      Map<String, dynamic> row, String field, Object value) async {
    try {
      await JamJotBackend.client
          .from('guardianships')
          .update({field: value}).eq('id', row['id']);
      ref.invalidate(kidGuardianshipsProvider(studentId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Only the primary caregiver can change permissions.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = JamJotBackend.client.auth.currentUser?.id;
    final rows =
        ref.watch(kidGuardianshipsProvider(studentId)).valueOrNull ?? [];
    final iAmPrimary = rows.any(
        (r) => r['profile_id'] == uid && r['is_primary'] == true);
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          iAmPrimary
              ? 'You are the primary caregiver. You decide what each helper can see and do.'
              : 'Permissions are set by the primary caregiver.',
          style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
        ),
        const SizedBox(height: 14),
        for (final r in rows) ...[
          Container(
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
                    child: Builder(builder: (context) {
                      final shown =
                          (r['display_name'] as String?)?.trim() ?? '';
                      final rel =
                          (r['relationship'] as String?)?.trim() ?? '';
                      final label = r['profile_id'] == uid
                          ? (shown.isEmpty ? 'You' : '$shown (you)')
                          : (shown.isEmpty ? 'Caregiver' : shown);
                      return Text(
                          '🧑 $label${rel.isEmpty ? '' : ' • $rel'}',
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700));
                    }),
                  ),
                  const SizedBox(width: 8),
                  if (r['is_primary'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: JamJotColors.marigoldTint,
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: JamJotColors.ink, width: 1),
                      ),
                      child: const Text('Primary',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                ]),
                if (r['is_primary'] != true) ...[
                  _grantSwitch(context, ref, r, 'can_message',
                      'Part of teacher chats', iAmPrimary),
                  _grantSwitch(context, ref, r, 'can_view_calendar',
                      'Sees the calendar', iAmPrimary),
                  _grantSwitch(context, ref, r, 'can_stock_rewards',
                      'Stocks market rewards', iAmPrimary),
                  _grantSwitch(context, ref, r, 'can_adjust_practice',
                      'Adjusts practice records', iAmPrimary),
                  _grantSwitch(
                      context, ref, r, 'can_pay', 'Can pay for lessons',
                      iAmPrimary),
                ] else
                  Text('Full access to everything for this kid.',
                      style: text.bodySmall
                          ?.copyWith(color: JamJotColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        if (iAmPrimary)
          JamJotCard(
            emoji: '✉️',
            tint: JamJotColors.blueberryTint,
            title: 'Invite another caregiver',
            subtitle:
                'Grandparents, co-parents & helpers — you choose what they can do.',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _inviteCaregiver(context, ref),
          ),
      ],
    );
  }

  Future<void> _inviteCaregiver(BuildContext context, WidgetRef ref) async {
    final kidName = (ref.read(myStudentsProvider).valueOrNull ?? [])
            .where((s) => s['id'] == studentId)
            .firstOrNull?['display_name'] as String? ??
        'our kid';
    final name = TextEditingController();
    final customRelation = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    const relations = [
      'Mom', 'Dad', 'Stepmom', 'Stepdad', 'Grandma', 'Grandpa',
      'Aunt', 'Uncle', 'Nanny / sitter',
    ];
    String relation = '';
    var fullAccess = false;
    var fullAccessAcknowledged = false;
    final grants = <String, bool>{
      'can_message': false,
      'can_view_calendar': true,
      'can_stock_rewards': false,
      'can_adjust_practice': false,
      'can_pay': false,
    };
    const labels = {
      'can_message': 'Part of teacher chats',
      'can_view_calendar': 'Sees the calendar',
      'can_stock_rewards': 'Stocks market rewards',
      'can_adjust_practice': 'Adjusts practice records',
      'can_pay': 'Can pay for lessons',
    };

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
            side: JamJotShape.border,
          ),
          title: const Text('Invite a caregiver'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(labelText: 'Their name'),
                  ),
                  const SizedBox(height: 12),
                  Text('Relationship to $kidName',
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final r in relations)
                        ChoiceChip(
                          label: Text(r),
                          selected: relation == r,
                          selectedColor: JamJotColors.blueberryTint,
                          onSelected: (_) => setState(() {
                            relation = r;
                            customRelation.clear();
                          }),
                        ),
                    ],
                  ),
                  TextField(
                    controller: customRelation,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: '…or something else'),
                    onChanged: (_) => setState(() => relation = ''),
                  ),
                  const SizedBox(height: 14),
                  const Text('What can they do?',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Full partner access',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle:
                        const Text('Everything on — like a second parent.'),
                    value: fullAccess,
                    onChanged: (v) => setState(() {
                      fullAccess = v;
                      if (!v) fullAccessAcknowledged = false;
                    }),
                  ),
                  if (fullAccess)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: JamJotColors.marigoldTint,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: JamJotColors.ink, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'They\'ll be able to do everything you can for $kidName — chats, calendar, rewards, practice records, and payments. For safety, each child keeps exactly ONE primary caregiver (you): only you can change caregivers\' permissions or remove chat messages.',
                            style: const TextStyle(fontSize: 13),
                          ),
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text(
                                'I understand and want to give full access',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                            value: fullAccessAcknowledged,
                            onChanged: (v) => setState(
                                () => fullAccessAcknowledged = v == true),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final key in grants.keys)
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(labels[key]!),
                        value: grants[key]!,
                        onChanged: (v) => setState(() => grants[key] = v),
                      ),
                  const SizedBox(height: 6),
                  const Text('How should the invite reach them?',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Phone number (for a text)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Email address (for an email)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: (name.text.trim().isEmpty ||
                      (fullAccess && !fullAccessAcknowledged))
                  ? null
                  : () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size(130, 44)),
              child: const Text('Create invite'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    final relationFinal = relation.isNotEmpty
        ? relation
        : (customRelation.text.trim().isNotEmpty
            ? customRelation.text.trim()
            : 'Caregiver');
    try {
      final uid = JamJotBackend.client.auth.currentUser!.id;
      final invite = await JamJotBackend.client
          .from('invitations')
          .insert({
            'kind': 'caregiver',
            'created_by': uid,
            'student_id': studentId,
            'preset_grants': {
              ...grants,
              'full_access': fullAccess,
              'caregiver_name': name.text.trim(),
              'relationship': relationFinal,
            },
          })
          .select()
          .single();
      if (!context.mounted) return;
      final link =
          'https://etorkelson44.github.io/JamJot/#/invite?token=${invite['token']}';
      final allowed = [
        for (final key in grants.keys)
          if (grants[key] == true) labels[key]!.toLowerCase(),
      ];
      final permissionLine = fullAccess
          ? 'do everything a parent can — full partner access'
          : (allowed.isEmpty
              ? 'follow along with their practice'
              : 'follow along with their practice, plus: ${allowed.join(', ')}');
      final message = '''Hi ${name.text.trim()}!

I set you up as $kidName's $relationFinal on JamJot — the app we use for music practice. You'll be able to $permissionLine.

Tap this link, create your free account, and you're in:
$link

(The link is just for you and works once.)''';

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
            side: JamJotShape.border,
          ),
          title: const Text('Invite ready — send it! 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  'A ready-written message for ${name.text.trim()} — send it however you like:'),
              const SizedBox(height: 12),
              if (phone.text.trim().isNotEmpty)
                FilledButton.icon(
                  onPressed: () => launchUrl(Uri.parse(
                      'sms:${phone.text.trim()}?body=${Uri.encodeComponent(message)}')),
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Send as text'),
                ),
              if (phone.text.trim().isNotEmpty)
                const SizedBox(height: 8),
              if (email.text.trim().isNotEmpty)
                FilledButton.icon(
                  onPressed: () => launchUrl(Uri.parse(
                      'mailto:${email.text.trim()}?subject=${Uri.encodeComponent("You're invited to $kidName's JamJot!")}&body=${Uri.encodeComponent(message)}')),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Send as email'),
                ),
              if (email.text.trim().isNotEmpty)
                const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: message));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Message copied!')));
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy the message'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not create the invite just now.')));
      }
    }
  }

  Widget _grantSwitch(BuildContext context, WidgetRef ref,
      Map<String, dynamic> row, String field, String label, bool editable) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: row[field] == true,
      onChanged: editable
          ? (v) => _setGrant(context, ref, row, field, v)
          : null,
    );
  }
}
