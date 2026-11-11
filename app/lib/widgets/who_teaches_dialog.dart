import 'package:flutter/material.dart';
import 'invite_message_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/student_instruments.dart';
import '../state/app_state.dart';
import '../theme/jamjot_theme.dart';

/// "Who teaches {instrument}?" (JJ-043-C). A caregiver says they teach it,
/// or that a teacher does: one already connected on JamJot, or someone new
/// by name. Reopen it any time to change or remove the teacher.
/// Returns true when something was saved.
Future<bool> showWhoTeachesDialog(
  BuildContext context,
  WidgetRef ref, {
  required String studentId,
  required String studentName,
  required StudentInstrument item,
}) async {
  final enrollments = await ref.read(kidEnrollmentsProvider(studentId).future);
  if (!context.mounted) return false;
  final linkable = [
    for (final e in enrollments)
      if ((e['instrument'] as String?)?.toLowerCase() ==
          item.instrument.toLowerCase())
        e,
  ];
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _WhoTeachesDialog(
        studentName: studentName, item: item, linkable: linkable),
  );
  if (saved == true) ref.invalidate(studentInstrumentsProvider(studentId));
  return saved == true;
}

class _WhoTeachesDialog extends StatefulWidget {
  const _WhoTeachesDialog(
      {required this.studentName, required this.item, required this.linkable});

  final String studentName;
  final StudentInstrument item;
  final List<Map<String, dynamic>> linkable;

  @override
  State<_WhoTeachesDialog> createState() => _WhoTeachesDialogState();
}

class _WhoTeachesDialogState extends State<_WhoTeachesDialog> {
  // 'me' | an enrollment id | 'new'
  late String _choice;
  late final TextEditingController _name;
  late final TextEditingController _knownAs;
  final _code = TextEditingController();
  final _lastInitial = TextEditingController();
  // For "a different teacher": are they already on JamJot?
  bool _onJamJot = false;
  bool _sendInvite = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (!it.taughtByTeacher) {
      _choice = 'me';
    } else if (it.enrollmentId != null &&
        widget.linkable.any((e) => e['id'] == it.enrollmentId)) {
      _choice = it.enrollmentId!;
    } else {
      _choice = 'new';
    }
    _name = TextEditingController(text: it.teacherName ?? '');
    _knownAs = TextEditingController(text: it.teacherKnownAs ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _knownAs.dispose();
    _code.dispose();
    _lastInitial.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final it = widget.item;
    final isNew = _choice == 'new';
    if (isNew && _onJamJot && _code.text.trim().isEmpty) {
      setState(() => _error = "Please enter the teacher's code.");
      return;
    }
    if (isNew && !_onJamJot && _name.text.trim().isEmpty) {
      setState(() => _error = "Please enter the teacher's name.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (isNew && _onJamJot) {
        final res = await connectTeacherByCode(
            code: _code.text, studentId: it.studentId, instrument: it.instrument);
        if (!res.ok) {
          setState(() {
            _busy = false;
            _error = res.error;
          });
          return;
        }
        if (_knownAs.text.trim().isNotEmpty) {
          await saveWhoTeaches(
              it.id,
              {
                'instruction': 'teacher',
                'teacher_known_as': _knownAs.text.trim(),
              });
        }
      } else {
        await saveWhoTeaches(
          it.id,
          whoTeachesFields(
            teacherInstructs: _choice != 'me',
            enrollmentId: (_choice == 'me' || isNew) ? null : _choice,
            teacherName: isNew ? _name.text : null,
            teacherKnownAs: _choice == 'me' ? null : _knownAs.text,
          ),
        );
        if (isNew && _sendInvite) {
          final link = await createTeacherInvite(
              studentId: it.studentId,
              instrument: it.instrument,
              teacherName: _name.text,
              knownAs: _knownAs.text,
              studentLastInitial: _lastInitial.text);
          if (mounted) await _showInvite(link);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save just now. Please try again.';
        });
      }
    }
  }

  Future<void> _showInvite(String link) {
    final teacher = _name.text.trim().isEmpty ? 'there' : _name.text.trim();
    final kid = widget.studentName;
    final instrument = widget.item.instrument;
    return showInviteMessageDialog(context,
        link: link,
        recipientName: teacher == 'there' ? 'your teacher' : teacher,
        subject: 'Join $kid\'s $instrument lessons on JamJot',
        message: '''Hi $teacher!

$kid and I have started using JamJot, an app that makes home practice really count: it listens while they play, so only real playing time is counted, and it keeps them motivated with little rewards for finishing their assigned songs.

I\'d love to connect you as $kid\'s $instrument teacher. You can assign each week\'s songs and see (and hear!) what was practiced before each lesson. A teacher account is free and takes about two minutes. Tap this link to join and you\'ll be connected right away:
$link

(The link is just for you. It works once and expires in 30 days.)''');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text('Who teaches ${widget.item.instrument}?'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: RadioGroup<String>(
            groupValue: _choice,
            onChanged: (v) => setState(() => _choice = v ?? _choice),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RadioListTile<String>(
                  value: 'me',
                  title: Text("I'm teaching this"),
                  subtitle: Text('A caregiver runs this instrument.'),
                ),
                for (final e in widget.linkable)
                  RadioListTile<String>(
                    value: e['id'] as String,
                    title: Text(
                        (e['teachers'] as Map?)?['display_name'] as String? ??
                            'Teacher'),
                    subtitle: const Text('Already connected on JamJot'),
                  ),
                const RadioListTile<String>(
                  value: 'new',
                  title: Text('A different teacher instructs'),
                ),
                if (_choice == 'new') ...[
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _onJamJot,
                    onChanged: (v) => setState(() => _onJamJot = v),
                    title: const Text('My teacher is already on JamJot'),
                  ),
                  if (_onJamJot)
                    TextField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                          labelText: "Teacher's code",
                          hintText: 'The code your teacher gave you'),
                    )
                  else ...[
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          const InputDecoration(labelText: "Teacher's name"),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _sendInvite,
                      onChanged: (v) => setState(() => _sendInvite = v ?? true),
                      title: const Text('Get an invitation link for them'),
                      subtitle: const Text(
                          'They join JamJot and this instrument fills in automatically.'),
                    ),
                    if (_sendInvite)
                      TextField(
                        controller: _lastInitial,
                        maxLength: 1,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                            labelText: "${widget.studentName}'s last initial (optional)",
                            counterText: '',
                            helperText:
                                'Shown to the teacher with their first name before they accept.'),
                      ),
                  ],
                  const SizedBox(height: 8),
                ],
                if (_choice != 'me')
                  TextField(
                    controller: _knownAs,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Known to my student as',
                        hintText: 'e.g. Ms. Lee'),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: text.bodyMedium
                          ?.copyWith(color: JamJotColors.recording)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save')),
      ],
    );
  }
}
