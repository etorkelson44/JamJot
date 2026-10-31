import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/supabase_service.dart';
import '../../theme/jamjot_theme.dart';

/// Past practice sessions for one student — the same truth for everyone:
/// kids browse their own, caregivers and teachers see it as the report.
final practiceHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, studentId) async {
  final rows = await JamJotBackend.client
      .from('sessions')
      .select('*, session_segments(*, assignments(title))')
      .eq('student_id', studentId)
      .not('ended_at', 'is', null)
      .order('started_at', ascending: false)
      .limit(30);
  return rows.cast<Map<String, dynamic>>();
});

class PracticeHistoryScreen extends ConsumerWidget {
  const PracticeHistoryScreen(
      {super.key, required this.studentId, required this.studentName});

  final String studentId;
  final String studentName;

  Future<void> _listen(BuildContext context, String audioPath) async {
    try {
      final url = await JamJotBackend.client.storage
          .from('recordings')
          .createSignedUrl(audioPath, 3600);
      await launchUrl(Uri.parse(url));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open that recording right now.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(practiceHistoryProvider(studentId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("$studentName's practices"),
        leading: BackButton(onPressed: () => context.go('/home')),
      ),
      body: SafeArea(
        child: sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
              child: Text('Could not load practices. Pull to retry.')),
          data: (sessions) {
            if (sessions.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'No practices yet — the first session will show up here, recording and all. 🎵',
                    textAlign: TextAlign.center,
                    style: text.titleMedium
                        ?.copyWith(color: JamJotColors.inkSoft),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  _SessionCard(session: sessions[i], onListen: _listen),
            );
          },
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onListen});

  final Map<String, dynamic> session;
  final Future<void> Function(BuildContext, String) onListen;

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
    final soundMinutes = ((session['total_seconds'] as num?)?.toInt() ?? 0) ~/ 60;
    final goalMet = session['goal_met'] == true;
    final audioPath = session['audio_path'] as String?;
    final segments = ((session['session_segments'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .where((s) => s['completed'] == true)
        .toList();

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
                  style:
                      text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (goalMet) const Text('🎯', style: TextStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$soundMinutes min of real sound • $wallMinutes min total',
            style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
          ),
          if (segments.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final seg in segments)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '🎼 ${(seg['assignments'] as Map?)?['title'] ?? 'Free play'}',
                        style: text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${((seg['seconds'] as num?)?.toInt() ?? 0) ~/ 60} min',
                      style: text.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _ratings[(seg['goal_results']
                              as Map?)?['self_rating']] ??
                          ((seg['goal_results'] as Map?)?['extra_practice'] ==
                                  true
                              ? '➕ extra practice'
                              : ''),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
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
