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
  final _studioName = TextEditingController();
  final Set<String> _instruments = {};
  String _mode = 'solo'; // solo | own_studio | join_studio
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _otherInstrument.dispose();
    _studioName.dispose();
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
    if (_mode == 'own_studio' && _studioName.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your studio name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final uid = JamJotBackend.client.auth.currentUser!.id;
      String? studioId;
      if (_mode == 'own_studio') {
        final studio = await JamJotBackend.client
            .from('studios')
            .insert({'owner_id': uid, 'name': _studioName.text.trim()})
            .select()
            .single();
        studioId = studio['id'] as String;
      }
      await JamJotBackend.client.from('teachers').insert({
        'profile_id': uid,
        'display_name': name,
        'instruments': instruments,
        'self_managed': true,
        if (studioId != null) 'studio_id': studioId,
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
                  Text('How do you teach?',
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('On my own'),
                        selected: _mode == 'solo',
                        selectedColor: JamJotColors.blueberryTint,
                        onSelected: (_) => setState(() => _mode = 'solo'),
                      ),
                      ChoiceChip(
                        label: const Text('I run a studio'),
                        selected: _mode == 'own_studio',
                        selectedColor: JamJotColors.blueberryTint,
                        onSelected: (_) => setState(() => _mode = 'own_studio'),
                      ),
                      ChoiceChip(
                        label: const Text('Joining a studio'),
                        selected: _mode == 'join_studio',
                        selectedColor: JamJotColors.blueberryTint,
                        onSelected: (_) =>
                            setState(() => _mode = 'join_studio'),
                      ),
                    ],
                  ),
                  if (_mode == 'own_studio') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _studioName,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          const InputDecoration(labelText: 'Studio name'),
                    ),
                  ],
                  if (_mode == 'join_studio') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: JamJotColors.marigoldTint,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: JamJotColors.ink, width: 2),
                      ),
                      child: Text(
                        'Ask your studio owner for their invite — studio invites arrive in an upcoming update. For now you can start on your own and join the studio later without losing anything.',
                        style: text.bodySmall,
                      ),
                    ),
                  ],
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
