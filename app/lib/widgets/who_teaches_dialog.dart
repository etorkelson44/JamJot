import 'package:flutter/material.dart';
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
    super.dispose();
  }

  Future<void> _save() async {
    if (_choice == 'new' && _name.text.trim().isEmpty) {
      setState(() => _error = "Please enter the teacher's name.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await saveWhoTeaches(
        widget.item.id,
        whoTeachesFields(
          teacherInstructs: _choice != 'me',
          enrollmentId: (_choice == 'me' || _choice == 'new') ? null : _choice,
          teacherName: _choice == 'new' ? _name.text : null,
          teacherKnownAs: _choice == 'me' ? null : _knownAs.text,
        ),
      );
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
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(labelText: "Teacher's name"),
                  ),
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
