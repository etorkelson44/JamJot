import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import 'add_student_screen.dart' show kInstruments;

class TeacherSetupScreen extends ConsumerStatefulWidget {
  const TeacherSetupScreen({super.key});

  @override
  ConsumerState<TeacherSetupScreen> createState() =>
      _TeacherSetupScreenState();
}

class _TeacherSetupScreenState extends ConsumerState<TeacherSetupScreen> {
  final _name = TextEditingController();
  final _otherInstrument = TextEditingController();
  final Set<String> _instruments = {};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _otherInstrument.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final other = _otherInstrument.text.trim();
    final instruments = {..._instruments, if (other.isNotEmpty) other}.toList();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter the name students will see.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final uid = JamJotBackend.client.auth.currentUser!.id;
      await JamJotBackend.client.from('teachers').insert({
        'profile_id': uid,
        'display_name': name,
        'instruments': instruments,
        'self_managed': true,
      });
      ref.invalidate(myTeacherProvider);
      if (mounted) context.go('/profiles');
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Could not save just now. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher setup')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Name students will see (e.g. Ms. Erika)'),
                  ),
                  const SizedBox(height: 20),
                  Text('What do you teach?',
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final i in kInstruments)
                        FilterChip(
                          label: Text(i),
                          selected: _instruments.contains(i),
                          selectedColor: JamJotColors.marigoldTint,
                          onSelected: (sel) => setState(() =>
                              sel ? _instruments.add(i) : _instruments.remove(i)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _otherInstrument,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Something else? Type it here'),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) ...[
                    Text(_error!,
                        style: text.bodyMedium
                            ?.copyWith(color: JamJotColors.recording)),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_busy ? 'Saving…' : 'Start teaching'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
