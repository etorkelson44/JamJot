import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../services/supabase_service.dart';
import '../state/app_state.dart';
import 'fan_stage.dart';
import '../screens/history/practice_history_screen.dart';
import '../screens/lesson/lesson_sheet_screen.dart';
import '../theme/jamjot_theme.dart';

/// A grown-up logs a practice that happened away from the app (piano at
/// grandma's, lesson warm-ups, a camp day). The backend writes it into the
/// same history and pays fair coins & fans, so everything adjusts.
Future<void> logOfflinePractice(BuildContext context, WidgetRef ref,
    {required Map<String, dynamic> kid}) async {
  final name = kid['display_name'] as String? ?? 'Student';
  var date = DateTime.now();
  final minutes = TextEditingController(text: '15');
  final note = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text('Log practice for $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'For practicing that happened without the app — it counts toward history, stre'
              'aks, coins and fans just like a recorded session.',
              style: TextStyle(fontSize: 12.5, color: JamJotColors.inkSoft),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => date = picked);
              },
              icon: const Icon(Icons.event, size: 18),
              label: Text(DateFormat('EEE, MMM d').format(date)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: minutes,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minutes practiced'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Note (optional) — what was practiced?'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: (int.tryParse(minutes.text.trim()) ?? 0) < 1 || (int.tryParse(minutes.text.trim()) ?? 0) > 240
                ? null : () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            child: const Text('Log it'),
          ),
        ],
      ),
    ),
  );
  final enteredMinutes = int.tryParse(minutes.text.trim()) ?? 0;
  final entryNote = note.text.trim();
  minutes.dispose();
  note.dispose();
  if (ok != true || !context.mounted) return;
  try {
    final data = Map<String, dynamic>.from(
        await JamJotBackend.client.rpc('log_practice_entry', params: {
      'p_student_id': kid['id'],
      'p_date': DateFormat('yyyy-MM-dd').format(date),
      'p_minutes': enteredMinutes,
      'p_note': entryNote,
      'p_request_id': const Uuid().v4(),
    }));
    if (!context.mounted) return;
    if (data['ok'] == true) {
      final sid = kid['id'] as String;
      ref.invalidate(berryBalanceProvider(sid));
      ref.invalidate(fanTotalProvider(sid));
      ref.invalidate(weeklyFansProvider(sid));
      ref.invalidate(weeklyProgressProvider(sid));
      ref.invalidate(practiceHistoryProvider(sid));
      ref.invalidate(sheetLessonsProvider(sid));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Logged! $name earned 🪙 ${data['coins']}${(data['fans'] as num? ?? 0) > 0 ? ' and 🕶️ ${data['fans']} fans' : ''}.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text((data['error'] as String?) ??
              'Could not log that — try again?')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not confirm this entry. Check practices before trying again.')));
    }
  }
}
