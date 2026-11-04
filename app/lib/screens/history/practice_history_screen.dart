import 'package:flutter/material.dart';
import '../../widgets/maestro_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../widgets/recording_player.dart';
import '../../state/app_state.dart';
import '../../widgets/fan_stage.dart';
import '../lesson/lesson_sheet_screen.dart';

import '../../services/supabase_service.dart';
import '../../theme/jamjot_theme.dart';

/// Past practice sessions for one student — the same truth for everyone:
/// kids browse their own, caregivers and teachers see it as the report.
final practiceHistoryProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, studentId) async {
  final rows = await JamJotBackend.client
      .from('sessions')
      .select('*, session_segments(*, assignments(title))')
      .eq('student_id', studentId)
      .not('ended_at', 'is', null)
      .order('started_at', ascending: false)
      .limit(30);
  // What each song earned, so summaries can show it.
  final rewards = <String, String>{};
  final totals = <String, List<int>>{};
  for (final table in ['berry_ledger', 'fan_ledger']) {
    final ledger = await JamJotBackend.client
        .from(table)
        .select('session_id, assignment_id, amount')
        .eq('student_id', studentId);
    final emoji = table == 'berry_ledger' ? '🪙' : '🕶️';
    for (final r in ledger) {
      final sessionId = r['session_id'] as String?;
      if (sessionId != null) {
        final entry = totals.putIfAbsent(sessionId, () => [0, 0]);
        entry[table == 'berry_ledger' ? 0 : 1] += (r['amount'] as num).toInt();
      }
      if (r['assignment_id'] == null) continue;
      final key = '${r['session_id']}/${r['assignment_id']}';
      rewards[key] =
          '${rewards[key] ?? ''} $emoji+${(r['amount'] as num).toInt()}'.trim();
    }
  }
  return {
    'sessions': rows.cast<Map<String, dynamic>>(),
    'rewards': rewards,
    'totals': totals,
  };
});

final canCorrectPracticeProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, sid) async {
  if (ref.watch(activeStudentProvider) != null) return false;
  return await JamJotBackend.client
          .rpc('can_correct_practice', params: {'sid': sid}) ==
      true;
});

class PracticeHistoryScreen extends StatelessWidget {
  const PracticeHistoryScreen(
      {super.key, required this.studentId, required this.studentName});

  final String studentId;
  final String studentName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$studentName's practices"),
        leading: BackButton(onPressed: () => context.go('/home')),
      ),
      body: SafeArea(child: PracticeHistoryList(studentId: studentId)),
    );
  }
}

/// The history list itself — embeddable anywhere (kid tabs, reports).
class PracticeHistoryList extends ConsumerWidget {
  const PracticeHistoryList({super.key, required this.studentId});

  final String studentId;

  Future<void> _listen(BuildContext context, String audioPath) async {
    try {
      final url = await JamJotBackend.client.storage
          .from('recordings')
          .createSignedUrl(audioPath, 3600);
      if (!context.mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Practice recording'),
                content: RecordingPlayer(url: url),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'))
                ],
              ));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open that recording right now.')));
      }
    }
  }

  Future<void> _correct(BuildContext context, WidgetRef ref,
      Map<String, dynamic> session, String action,
      {String? segmentId, String? path}) async {
    final minutes = TextEditingController(
        text: '${((session['total_seconds'] as num?)?.toInt() ?? 0) ~/ 60}');
    int? chosenMinutes;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                scrollable: true,
                title: Text(action == 'minutes'
                    ? 'Adjust practice minutes'
                    : action == 'automatic_minutes'
                        ? 'Use original minutes?'
                        : 'Delete this practice record?'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(action == 'minutes'
                          ? 'These minutes will replace the recording minutes for goals, coins and fans. The recordings stay available.'
                          : action == 'automatic_minutes'
                              ? 'Goals and rewards will use the remaining recorded practice again.'
                              : 'This removes ${action == 'delete_session' ? 'the entire session and its recordings' : action == 'delete_song' ? 'this song practice and its recordings' : 'this recording and its counted minutes'}. Goals, coins and fans will adjust. This cannot be undone.'),
                      const SizedBox(height: 12),
                      if (action == 'minutes')
                        TextField(
                          controller: minutes,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Credited minutes (0–240)'),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                          'Previously bought rewards stay owned. If a correction reduces the coin pot below zero, future coins cover the difference.'),
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: action == 'minutes' &&
                              (int.tryParse(minutes.text) == null ||
                                  int.parse(minutes.text) < 0 ||
                                  int.parse(minutes.text) > 240)
                          ? null
                          : () {
                              chosenMinutes = int.tryParse(minutes.text);
                              Navigator.of(context).pop(true);
                            },
                      child: Text(action == 'minutes'
                          ? 'Save minutes'
                          : action == 'automatic_minutes'
                              ? 'Use original minutes'
                              : 'Delete')),
                ],
              ),
            ));
    minutes.dispose();
    if (confirmed != true || !context.mounted) return;
    try {
      final response = await JamJotBackend.client.functions
          .invoke('correct-practice', body: {
        'session_id': session['id'],
        'action': action,
        if (segmentId != null) 'segment_id': segmentId,
        if (path != null) 'path': path,
        if (action == 'minutes') 'minutes': chosenMinutes,
      });
      final data = response.data as Map? ?? {};
      if (data['ok'] != true) throw StateError('Correction failed');
      ref.invalidate(practiceHistoryProvider(studentId));
      ref.invalidate(weeklyProgressProvider(studentId));
      ref.invalidate(berryBalanceProvider(studentId));
      ref.invalidate(fanTotalProvider(studentId));
      ref.invalidate(weeklyFansProvider(studentId));
      ref.invalidate(sheetLessonsProvider(studentId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['cleanup_pending'] == true
              ? 'Practice updated. Private recording deletion is queued for retry.'
              : 'Practice updated. Minutes, goals and rewards have been recalculated.'),
          action: data['cleanup_pending'] == true
              ? SnackBarAction(
                  label: 'Retry deletion',
                  onPressed: () async {
                    try {
                      final retry = await JamJotBackend.client.functions
                          .invoke('correct-practice', body: {
                        'action': 'retry_cleanup',
                        'student_id': studentId
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                (retry.data as Map?)?['cleanup_pending'] ==
                                        false
                                    ? 'Private recordings deleted.'
                                    : 'Recording deletion is still queued.')));
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Recording deletion is still queued.')));
                      }
                    }
                  })
              : null,
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'The correction could not be confirmed. Refresh practices before trying again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(practiceHistoryProvider(studentId));
    final text = Theme.of(context).textTheme;
    final canCorrect =
        ref.watch(canCorrectPracticeProvider(studentId)).valueOrNull ?? false;

    return sessionsAsync.when(
      loading: () => const Center(child: MaestroLoader()),
      error: (_, __) => Center(
          child: TextButton(
              onPressed: () =>
                  ref.invalidate(practiceHistoryProvider(studentId)),
              child: const Text('Could not load practices. Tap to retry.'))),
      data: (bundle) {
        final sessions =
            (bundle['sessions'] as List).cast<Map<String, dynamic>>();
        final rewards = bundle['rewards'] as Map<String, String>;
        if (sessions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'No practices yet — the first session will show up here, recording and all. 🎵',
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: JamJotColors.inkSoft),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _SessionCard(
              session: sessions[i],
              rewards: rewards,
              totalRewards:
                  (bundle['totals'] as Map?)?[sessions[i]['id']] as List<int>?,
              onListen: _listen,
              onCorrect: canCorrect
                  ? (action, {segmentId, path}) => _correct(
                      context, ref, sessions[i], action,
                      segmentId: segmentId, path: path)
                  : null),
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard(
      {required this.session,
      required this.rewards,
      required this.onListen,
      this.onCorrect,
      this.totalRewards});

  final Map<String, dynamic> session;
  final Map<String, String> rewards;
  final List<int>? totalRewards;
  final Future<void> Function(BuildContext, String) onListen;
  final Future<void> Function(String action, {String? segmentId, String? path})?
      onCorrect;

  /// "7:42 PM • 1:50 sound / 2:20 rec" — each clip's own stamp.
  static String _clipLabel(Map<String, dynamic> clip) {
    String fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    final parts = <String>[];
    final at = clip['at'] as String?;
    if (at != null) {
      parts.add(DateFormat('h:mm a').format(DateTime.parse(at).toLocal()));
    }
    final sound = (clip['sound_seconds'] as num?)?.toInt();
    final wall = (clip['wall_seconds'] as num?)?.toInt();
    if (sound != null && wall != null) {
      parts.add('${fmt(sound)} sound / ${fmt(wall)} rec');
    }
    return parts.isEmpty ? 'Listen' : parts.join(' • ');
  }

  static const _ratings = {
    'got_it': '🌟 I got it down!',
    'getting_there': '👍 Getting there',
    'working_on_it': '💪 Still working on it',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final started = DateTime.parse(session['started_at'] as String).toLocal();
    final ended = DateTime.parse(session['ended_at'] as String).toLocal();
    final wallMinutes = ended.difference(started).inMinutes;
    final soundMinutes =
        ((session['total_seconds'] as num?)?.toInt() ?? 0) ~/ 60;
    final goalMet = session['goal_met'] == true;
    final audioPath = session['audio_path'] as String?;
    final segments = ((session['session_segments'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
      ..sort((a, b) => (b['completed'] == true ? 1 : 0)
          .compareTo(a['completed'] == true ? 1 : 0));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
        border: Border.all(color: JamJotColors.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, MMM d • h:mm a').format(started),
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (goalMet) const Text('🎯', style: TextStyle(fontSize: 18)),
              if (onCorrect != null)
                PopupMenuButton<String>(
                  tooltip: 'Correct practice',
                  onSelected: (action) => onCorrect!(action),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'minutes',
                        child: Text('Adjust credited minutes')),
                    if (session['manual_override_seconds'] != null)
                      const PopupMenuItem(
                          value: 'automatic_minutes',
                          child: Text('Use original minutes again')),
                    const PopupMenuItem(
                        value: 'delete_session',
                        child: Text('Delete entire practice')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (totalRewards != null)
            Text(
                '${totalRewards![0]} coins · ${totalRewards![1]} fans credited',
                style: text.bodySmall),
          if (session['manual_override_seconds'] != null)
            Text('$soundMinutes min credited by a grown-up · recordings kept',
                style: text.bodySmall),
          if (session['source'] == 'manual') ...[
            Text(
              '✍️ Logged by a grown-up • $soundMinutes min of practice',
              style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (((session['entry_note'] as String?) ?? '').trim().isNotEmpty)
              Text((session['entry_note'] as String).trim(),
                  style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
          ] else
            Text(
              '$soundMinutes min of real sound • $wallMinutes min total',
              style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
            ),
          if (segments.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final seg in segments) ...[
              Builder(builder: (context) {
                final title =
                    (seg['assignments'] as Map?)?['title'] ?? 'Free play';
                // Prefer stamped clips; fall back to bare paths (older data).
                final stamped = ((seg['audio_clips'] as List?) ?? [])
                    .cast<Map<String, dynamic>>();
                final clips = stamped.isNotEmpty
                    ? stamped
                    : [
                        for (final p in ((seg['audio_paths'] as List?) ?? [])
                            .cast<String>())
                          {'path': p}
                      ];
                final rating =
                    _ratings[(seg['goal_results'] as Map?)?['self_rating']];
                final extra =
                    (seg['goal_results'] as Map?)?['extra_practice'] == true;
                final inProgress = seg['completed'] != true;
                final rewardText =
                    rewards['${session['id']}/${seg['assignment_id']}'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('🎼 $title',
                                style: text.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                          ),
                          if (onCorrect != null)
                            IconButton(
                              tooltip: 'Delete this song practice',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => onCorrect!('delete_song',
                                  segmentId: seg['id'] as String),
                            ),
                          Builder(builder: (context) {
                            final soundMin =
                                ((seg['seconds'] as num?)?.toInt() ?? 0) ~/ 60;
                            final wallMin =
                                ((seg['wall_seconds'] as num?)?.toInt() ?? 0) ~/
                                    60;
                            return Text(
                              wallMin > 0
                                  ? '$soundMin min sound • $wallMin min recorded'
                                  : '$soundMin min',
                              style: text.bodySmall,
                            );
                          }),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (rating != null)
                            Text(rating, style: text.bodySmall),
                          if (extra)
                            Text('➕ extra practice', style: text.bodySmall),
                          if (inProgress && !extra && rating == null)
                            Text('⏳ in progress',
                                style: text.bodySmall
                                    ?.copyWith(color: JamJotColors.inkSoft)),
                          if (rewardText != null &&
                              !extra &&
                              totalRewards == null)
                            Text(rewardText, style: text.bodySmall),
                          for (final clip in clips)
                            InputChip(
                              onDeleted: onCorrect != null &&
                                      clip['sound_seconds'] != null
                                  ? () => onCorrect!('delete_recording',
                                      segmentId: seg['id'] as String,
                                      path: clip['path'] as String)
                                  : null,
                              deleteButtonTooltipMessage:
                                  'Delete this recording',
                              avatar: const Icon(Icons.play_arrow, size: 16),
                              label: Text(_clipLabel(clip)),
                              onPressed: () =>
                                  onListen(context, clip['path'] as String),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
          if (audioPath != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => onListen(context, audioPath),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Listen to this practice'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44)),
            ),
          ],
        ],
      ),
    );
  }
}
