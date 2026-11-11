import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import '../../services/student_instruments.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/dancing_maestro.dart';
import '../../widgets/invite_message_dialog.dart' show notifyInviteAccepted;
import '../../widgets/instrument_icon.dart';
import '../../widgets/maestro_loader.dart';

/// Where a teacher's invite link lands. Signed out: a warm hello and the
/// account buttons. Signed in: pick (or add) the kid and connect.
const _expiredInviteMessage =
    'This invite has expired. Please reach out to the person who invited you and ask them to send you a new one.';
const _usedInviteMessage =
    'This invite was already used. If you still need to join, please ask the person who invited you to send a new one.';

/// Turns a server message about a bad invite into something a person can act on.
String friendlyInviteError(String? message) {
  final m = (message ?? '').toLowerCase();
  if (m.contains('expired')) return _expiredInviteMessage;
  if (m.contains('already used')) return _usedInviteMessage;
  if (m.contains('not found')) {
    return 'We could not find this invite. It may have been replaced. Please ask the person who invited you to send a new one.';
  }
  return message ?? 'Something went wrong. Try again?';
}

/// A failed call to the invite function (the server answers 410 for an expired or used invite).
String inviteErrorMessage(Object e, {bool loading = false}) {
  if (e is FunctionException) {
    final d = e.details;
    final msg = d is Map ? d['error'] as String? : (d is String ? d : null);
    if (msg != null) return friendlyInviteError(msg);
    if (e.status == 410) return _expiredInviteMessage;
    if (e.status == 404) return friendlyInviteError('not found');
  }
  return loading
      ? 'Could not load this invite. Try again?'
      : 'Something went wrong. Try again?';
}

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  Map<String, dynamic>? _info;

  /// Set when this link is a caregiver's invitation to a teacher.
  Map<String, dynamic>? _teacherInvite;
  bool _previewDone = false;
  String? _error;
  bool _busy = false;
  String? _pickedStudentId;
  final _newKidName = TextEditingController();

  @override
  void initState() {
    super.initState();
    pendingInviteToken = widget.token;
    _checkTeacherInvite();
  }

  /// Teacher invites are looked up first (works signed out); anything else
  /// falls through to the family/caregiver invite flow.
  Future<void> _checkTeacherInvite() async {
    final preview = await teacherInvitePreview(widget.token);
    if (!mounted) return;
    setState(() {
      _teacherInvite = preview;
      _previewDone = true;
    });
    if (preview == null && JamJotBackend.signedIn) _loadInfo();
  }

  Future<void> _acceptTeacher() async {
    setState(() => _busy = true);
    try {
      final res = await acceptTeacherInvite(widget.token);
      if (res['ok'] == true) {
        pendingInviteToken = null;
        notifyInviteAccepted(widget.token);   // lets the inviter know by email (best effort)
        ref.invalidate(myTeacherProvider);
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Connected! 🎉'),
            content: Text(
                "You're now ${res['student']}'s ${res['instrument']} teacher on JamJot."),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Let's go"),
              ),
            ],
          ),
        );
        if (mounted) context.go('/gate');
      } else if (res['error'] == 'needs_teacher_profile') {
        if (mounted) context.go('/teacher-setup');
      } else {
        setState(() {
          _error = friendlyInviteError(res['error'] as String?);
          _busy = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = inviteErrorMessage(e);
        _busy = false;
      });
    }
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
          _error = friendlyInviteError(data['error'] as String?);
        } else {
          _info = data;
        }
      });
    } catch (e) {
      setState(() => _error = inviteErrorMessage(e, loading: true));
    }
  }

  Future<void> _acceptCaregiver() async {
    setState(() => _busy = true);
    try {
      final res = await JamJotBackend.client.functions.invoke(
          'redeem-invite',
          body: {'token': widget.token, 'accept': true});
      final data = res.data as Map<String, dynamic>? ?? {};
      if (data['mode'] == 'redeemed') {
        pendingInviteToken = null;
        notifyInviteAccepted(widget.token);   // lets the inviter know by email (best effort)
        ref.invalidate(myStudentsProvider);
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
                side: JamJotShape.border,
              ),
              title: const Text('Welcome to the team! 🎉'),
              content: Text(
                  'You are now one of ${data['student_name']}\'s caregivers. You can cheer along from your home screen.'),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(96, 44)),
                  child: const Text("Let's go"),
                ),
              ],
            ),
          );
          if (mounted) context.go('/gate');
        }
      } else {
        setState(() {
          _error = friendlyInviteError(data['error'] as String?);
          _busy = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = inviteErrorMessage(e);
        _busy = false;
      });
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
        notifyInviteAccepted(widget.token);   // lets the inviter know by email (best effort)
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
          _error = friendlyInviteError(data['error'] as String?);
          _busy = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = inviteErrorMessage(e);
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
    final ti = _teacherInvite;
    if (!_previewDone) {
      body = const Center(child: MaestroLoader());
    } else if (ti != null && ti['status'] != 'ok') {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('😕', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          Text(
              ti['status'] == 'used'
                  ? friendlyInviteError('This invite was already used')
                  : friendlyInviteError('This invite has expired'),
              textAlign: TextAlign.center,
              style: text.titleMedium),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Go home'),
          ),
        ],
      );
    } else if (ti != null) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: DancingMaestro(size: 130)),
          const SizedBox(height: 12),
          Center(child: InstrumentIcon(ti['instrument'] as String?, size: 56)),
          const SizedBox(height: 8),
          Text(
            "You're invited to teach ${ti['student']} ${ti['instrument']} on JamJot! 🎉",
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            signedIn
                ? "Accept and you're connected, with lessons, assignments and practice flowing between you."
                : 'Create your free teacher account (or sign in) and the connection finishes automatically.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: JamJotColors.recording)),
          ],
          const SizedBox(height: 20),
          if (signedIn)
            FilledButton(
              onPressed: _busy ? null : _acceptTeacher,
              child: Text(_busy ? 'Connecting…' : 'Accept and connect'),
            )
          else ...[
            FilledButton(
              onPressed: () => context.go('/signin?create=1&role=teacher'),
              child: const Text('Create my teacher account'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.go('/signin'),
              child: const Text('I already have an account'),
            ),
          ],
        ],
      );
    } else if (!signedIn) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: DancingMaestro(size: 150)),
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
      body = const Center(child: MaestroLoader());
    } else if (_info!['kind'] == 'caregiver') {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: DancingMaestro(size: 130)),
          const SizedBox(height: 12),
          Text(
            _info!['caregiver_name'] != null
                ? "Hi ${_info!['caregiver_name']}! You're invited to be ${_info!['student_name']}'s ${(_info!['relationship'] as String?)?.toLowerCase() ?? 'caregiver'} on JamJot! 🎉"
                : "You're invited to be one of ${_info!['student_name']}'s caregivers! 🎉",
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'You\'ll be able to follow their practice journey — and whatever else their primary caregiver has switched on for you.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _acceptCaregiver,
            child: Text(_busy ? 'Joining…' : "Count me in!"),
          ),
        ],
      );
    } else {
      final hint = _info!['student_hint'] as String?;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const Center(child: DancingMaestro(size: 120)),
          const SizedBox(height: 10),
          if (_info!['instrument'] != null) ...[
            Center(
                child: InstrumentIcon(_info!['instrument'] as String?,
                    size: 56)),
            const SizedBox(height: 8),
          ],
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
