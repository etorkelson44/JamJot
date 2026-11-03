import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';

const kInstruments = [
  'Piano', 'Violin', 'Guitar', 'Voice', 'Cello', 'Drums',
  'Flute', 'Trumpet', 'Clarinet', 'Saxophone', 'Ukulele', 'Viola',
];

class AddStudentScreen extends ConsumerStatefulWidget {
  const AddStudentScreen({super.key});

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _otherInstrument = TextEditingController();
  final Set<String> _instruments = {};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _otherInstrument.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final pin = _pin.text.trim();
    final other = _otherInstrument.text.trim();
    final instruments = {..._instruments, if (other.isNotEmpty) other}.toList();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }
    if (instruments.isEmpty) {
      setState(() => _error = 'Pick at least one instrument.');
      return;
    }
    if (pin.isNotEmpty && pin.length != 4) {
      setState(() => _error = 'The PIN should be exactly 4 digits.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final uid = JamJotBackend.client.auth.currentUser!.id;
      final student = await JamJotBackend.client
          .from('students')
          .insert({
            'display_name': name,
            'instruments': instruments,
            'pin_hash': pin.isEmpty ? null : hashPin(pin),
            'created_by': uid,
          })
          .select()
          .single();
      await JamJotBackend.client.from('guardianships').insert({
        'student_id': student['id'],
        'profile_id': uid,
        'is_primary': true,
        'can_message': true,
        'can_view_calendar': true,
        'family_event_level': 'edit',
        'can_stock_rewards': true,
        'can_adjust_practice': true,
        'can_pay': true,
      });
      ref.invalidate(myStudentsProvider);
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
      appBar: AppBar(title: const Text('Add a kid')),
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
                        labelText: 'First name or nickname'),
                  ),
                  const SizedBox(height: 20),
                  Text('What do they play?',
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
                          selectedColor: JamJotColors.blueberryTint,
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
                  Text('Profile PIN (optional)',
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    'A 4-digit code this kid will use to protect their profile from siblings.',
                    style:
                        text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                        labelText: '4 digits', counterText: ''),
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
                    child: Text(_busy ? 'Saving…' : 'Add to the family'),
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
