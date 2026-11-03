import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/jamjot_card.dart';

/// All my chats — one per student-teacher connection.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(myChatsProvider).valueOrNull ?? [];
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        leading: BackButton(onPressed: () => context.go('/home')),
      ),
      body: SafeArea(
        child: chats.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'No chats yet. A chat opens for each student–teacher connection — and caregivers join when the primary caregiver allows messaging.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium
                        ?.copyWith(color: JamJotColors.inkSoft),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  for (final c in chats) ...[
                    JamJotCard(
                      emoji: '💬',
                      tint: JamJotColors.blueberryTint,
                      title: '${c['student_name']} × ${c['teacher_name']}',
                      subtitle: c['instrument'] as String?,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(
                          '/chat?enrollment=${c['enrollment_id']}&title=${Uri.encodeComponent('${c['student_name']} × ${c['teacher_name']}')}&primary=${c['i_am_primary'] == true ? 1 : 0}&teacher=${c['teacher_profile_id']}'),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
      ),
    );
  }
}

/// One chat: teacher + student + permitted caregivers, read-locked.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.enrollmentId,
    required this.title,
    required this.iAmPrimary,
    required this.teacherProfileId,
  });

  final String enrollmentId;
  final String title;
  final bool iAmPrimary;
  final String teacherProfileId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Timer? _poll;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await JamJotBackend.client
          .from('messages')
          .select('*, message_reads(reader_id)')
          .eq('enrollment_id', widget.enrollmentId)
          .order('created_at', ascending: true)
          .limit(200);
      if (!mounted) return;
      setState(() => _messages = rows.cast<Map<String, dynamic>>());
      _markRead();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } catch (_) {}
  }

  Future<void> _markRead() async {
    final uid = JamJotBackend.client.auth.currentUser!.id;
    final unread = [
      for (final m in _messages)
        if (m['sender_id'] != uid &&
            !((m['message_reads'] as List?) ?? [])
                .any((r) => r['reader_id'] == uid))
          {'message_id': m['id'], 'reader_id': uid},
    ];
    if (unread.isEmpty) return;
    try {
      await JamJotBackend.client
          .from('message_reads')
          .upsert(unread, onConflict: 'message_id,reader_id');
    } catch (_) {}
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final uid = JamJotBackend.client.auth.currentUser!.id;
      await JamJotBackend.client.from('messages').insert({
        'enrollment_id': widget.enrollmentId,
        'sender_id': uid,
        'body': body,
      });
      _input.clear();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not send — please try again.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _maybeDelete(Map<String, dynamic> m) async {
    if (!widget.iAmPrimary || m['deleted_at'] != null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: const Text('Remove this message?'),
        content: const Text(
            'As the primary caregiver you can remove messages to keep this chat safe. The removal is recorded.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: JamJotColors.recording,
                minimumSize: const Size(96, 44)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final uid = JamJotBackend.client.auth.currentUser!.id;
      await JamJotBackend.client.from('messages').update({
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'deleted_by': uid,
      }).eq('id', m['id']);
      await _load();
    } catch (_) {}
  }

  String _senderLabel(Map<String, dynamic> m, String uid) {
    if (m['sender_id'] == uid) return 'You';
    if (m['sender_id'] == widget.teacherProfileId) return 'Teacher';
    return 'Family';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final uid = JamJotBackend.client.auth.currentUser!.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: BackButton(onPressed: () => context.go('/messages')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: JamJotColors.blueberryTint,
              child: Text(
                '🔒 Everyone in this chat sees every message. Once read, messages cannot be edited or unsent.',
                style: text.labelSmall?.copyWith(color: JamJotColors.ink),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  final mine = m['sender_id'] == uid;
                  final deleted = m['deleted_at'] != null;
                  final readByOther = ((m['message_reads'] as List?) ?? [])
                      .any((r) => r['reader_id'] != m['sender_id']);
                  final when = DateFormat('MMM d, h:mm a').format(
                      DateTime.parse(m['created_at'] as String).toLocal());
                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: GestureDetector(
                      onLongPress: () => _maybeDelete(m),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          color: deleted
                              ? JamJotColors.neutral
                              : (mine ? JamJotColors.ink : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: JamJotColors.ink, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_senderLabel(m, uid)} • $when',
                              style: text.labelSmall?.copyWith(
                                  color: mine && !deleted
                                      ? Colors.white70
                                      : JamJotColors.inkSoft),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              deleted
                                  ? 'Removed by the primary caregiver'
                                  : m['body'] as String,
                              style: text.bodyMedium?.copyWith(
                                fontStyle:
                                    deleted ? FontStyle.italic : null,
                                color: deleted
                                    ? JamJotColors.inkSoft
                                    : (mine ? Colors.white : JamJotColors.ink),
                              ),
                            ),
                            if (mine && !deleted && readByOther)
                              Text('Read ✓',
                                  style: text.labelSmall
                                      ?.copyWith(color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Write a message…',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(
                        backgroundColor: JamJotColors.ink,
                        minimumSize: const Size(48, 48)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
