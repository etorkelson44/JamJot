import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/dancing_note.dart';

/// Where a teacher's invite link lands. Signed out: a warm hello and the
/// account buttons. Signed in: pick (or add) the kid and connect.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  Map<String, dynamic>? _info;
  String? _error;
  bool _busy = false;
  String? _pickedStudentId;
  final _newKidName = TextEditingController();

  @override
  void initState() {
    super.initState();
    pendingInviteToken = widget.token;
    if (JamJotBackend.signedIn) _loadInfo();
  }

  @override
  void dispose() {
    _newKidName.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    try {
      final res = await JamJotBackend.client.functions
          .invoke('redeem-invite', body: {'token': widget.token});
      final data = res.data as Map<String, dynamic>? ?? {};
      setState(() {
        if (data['error'] != null) {
          _error = data['error'] as String;
        } else {
          _info = data;
        }
      });
    } catch (_) {
      setState(() => _error = 'Could not load this invite. Try again?');
    }
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{'token': widget.token};
      if (_pickedStudentId != null) {
        body['student_id'] = _pickedStudentId;
      } else if (_newKidName.text.trim().isNotEmpty) {
        body['new_student'] = {
          'name': _newKidName.text.trim(),
          'instruments': [_info?['instrument'] ?? 'Music'],
        };
      } else {
        setState(() {
          _busy = false;
          _error = null;
        });
        return;
      }
      final res = await JamJotBackend.client.functions
          .invoke('redeem-invite', body: body);
      final data = res.data as Map<String, dynamic>? ?? {};
      if (data['mode'] == 'redeemed') {
        pendingInviteToken = null;
        ref.invalidate(myStudentsProvider);
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
                side: JamJotShape.border,
              ),
              title: const Text('Connected! 🎉'),
              content: Text(
                  '${data['teacher_name']} is now linked with your family. Lessons, assignments, and practice all flow between you.'),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style:
                      FilledButton.styleFrom(minimumSize: const Size(96, 44)),
                  child: const Text("Let's go"),
                ),
              ],
            ),
          );
          if (mounted) context.go('/profiles');
        }
      } else {
        setState(() {
          _error = (data['error'] as String?) ?? 'Something went wrong.';
          _busy = false;
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Try again?';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final signedIn = JamJotBackend.signedIn;
    final students = signedIn
        ? (ref.watch(myStudentsProvider).valueOrNull ?? [])
        : <Map<String, dynamic>>[];

    Widget body;
    if (!signedIn) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: DancingNote(size: 150)),
          const SizedBox(height: 12),
          Text("You're invited to JamJot! 🎉",
              textAlign: TextAlign.center,
              style:
                  text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'A music teacher wants to connect with your family. Create your free grown-up account (or sign in) and the connection finishes automatically.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go('/signin?create=1&role=family'),
            child: const Text('Create my account'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.go('/signin'),
            child: const Text('I already have an account'),
          ),
        ],
      );
    } else if (_error != null) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('😕', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center, style: text.titleMedium),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Go home'),
          ),
        ],
      );
    } else if (_info == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final hint = _info!['student_hint'] as String?;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const Center(child: DancingNote(size: 120)),
          const SizedBox(height: 10),
          Text(
            '${_info!['teacher_name']}${_info!['studio_name'] != null ? ' (${_info!['studio_name']})' : ''} invites your family to connect for ${_info!['instrument'] ?? 'music'} lessons${hint != null ? ' — for $hint' : ''}.',
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text('Which musician is this for?',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          for (final s in students)
            RadioListTile<String>(
              value: s['id'] as String,
              groupValue: _pickedStudentId,
              title: Text(s['display_name'] as String),
              onChanged: (v) => setState(() {
                _pickedStudentId = v;
                _newKidName.clear();
              }),
            ),
          TextField(
            controller: _newKidName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: hintTextForNewKid,
                prefixIcon: Icon(Icons.person_add_alt)),
            onChanged: (_) => setState(() => _pickedStudentId = null),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _accept,
            child: Text(_busy ? 'Connecting…' : 'Connect us!'),
          ),
        ],
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

const hintTextForNewKid = '…or add a new kid: their first name';
