import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/dancing_note.dart';

enum _Phase { starting, recording, saving, celebrate, micDenied, error }

class PracticeSessionScreen extends ConsumerStatefulWidget {
  const PracticeSessionScreen({super.key});

  @override
  ConsumerState<PracticeSessionScreen> createState() =>
      _PracticeSessionScreenState();
}

class _PracticeSessionScreenState
    extends ConsumerState<PracticeSessionScreen> {
  final _recorder = AudioRecorder();
  _Phase _phase = _Phase.starting;
  String? _sessionId;
  int _seconds = 0;
  Timer? _ticker;
  int _minutes = 0;
  int _berries = 0;
  bool _goalMet = false;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    final student = ref.read(activeStudentProvider);
    if (student == null) {
      if (mounted) context.go('/practice');
      return;
    }
    try {
      final hasMic = await _recorder.hasPermission();
      if (!hasMic) {
        setState(() => _phase = _Phase.micDenied);
        return;
      }
      await _recorder.start(const RecordConfig(), path: '');
      final row = await JamJotBackend.client
          .from('sessions')
          .insert({'student_id': student['id']})
          .select()
          .single();
      _sessionId = row['id'] as String;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
      setState(() => _phase = _Phase.recording);
    } catch (_) {
      setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _finish() async {
    setState(() => _phase = _Phase.saving);
    _ticker?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {/* recording is best-effort in this version */}
    try {
      await JamJotBackend.client.from('sessions').update({
        'ended_at': DateTime.now().toUtc().toIso8601String(),
        'total_seconds': _seconds,
      }).eq('id', _sessionId!);
      final res = await JamJotBackend.client.functions
          .invoke('award-practice', body: {'session_id': _sessionId});
      final data = res.data as Map<String, dynamic>? ?? {};
      setState(() {
        _minutes = (data['minutes'] as num?)?.toInt() ?? _seconds ~/ 60;
        _berries = (data['berries'] as num?)?.toInt() ?? 0;
        _goalMet = data['goal_met'] == true;
        _phase = _Phase.celebrate;
      });
    } catch (_) {
      setState(() {
        _minutes = _seconds ~/ 60;
        _berries = 0;
        _goalMet = false;
        _phase = _Phase.celebrate;
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  String get _clock {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final student = ref.watch(activeStudentProvider);
    final name = student?['display_name'] ?? 'musician';

    Widget body;
    switch (_phase) {
      case _Phase.starting:
        body = const Center(child: CircularProgressIndicator());
      case _Phase.micDenied:
        body = _Message(
          emoji: '🎤',
          title: 'JamJot needs to hear you!',
          body:
              'Practice only counts when it is really heard. Please allow the microphone in your browser and try again.',
          button: 'Try again',
          onTap: () {
            setState(() => _phase = _Phase.starting);
            _begin();
          },
        );
      case _Phase.error:
        body = _Message(
          emoji: '😅',
          title: 'Something hiccuped',
          body: 'Could not start the session. Give it another try!',
          button: 'Try again',
          onTap: () {
            setState(() => _phase = _Phase.starting);
            _begin();
          },
        );
      case _Phase.saving:
        body = const Center(child: CircularProgressIndicator());
      case _Phase.recording:
        body = Column(
          children: [
            const SizedBox(height: 8),
            const _RecordingBanner(),
            const Spacer(),
            const DancingNote(size: 150),
            const SizedBox(height: 16),
            Text(_clock,
                style: text.displayLarge?.copyWith(
                    fontWeight: FontWeight.w700, letterSpacing: 2)),
            Text('Keep the music coming, $name!',
                style:
                    text.titleMedium?.copyWith(color: JamJotColors.inkSoft)),
            const Spacer(),
            FilledButton(
              onPressed: _finish,
              child: const Text("I'm done"),
            ),
            const SizedBox(height: 8),
            Text(
              'Sound checking and song matching join in a future update — for now every minute counts.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
            ),
          ],
        );
      case _Phase.celebrate:
        body = Column(
          children: [
            const Spacer(),
            const Text('🎉', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            Text('You practiced $_minutes minute${_minutes == 1 ? '' : 's'}!',
                textAlign: TextAlign.center,
                style: text.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (_berries > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: JamJotColors.plumTint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: JamJotColors.ink, width: 2),
                ),
                child: Text('🫐 +$_berries berries in your jar!',
                    style: text.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (_goalMet)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('Session goal reached — amazing!',
                      style: text.titleSmall
                          ?.copyWith(color: JamJotColors.leaf)),
                ),
            ] else ...[
              Text(
                'The session goal is 15 minutes — a little more next time and the berries start rolling in!',
                textAlign: TextAlign.center,
                style:
                    text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
              ),
            ],
            const Spacer(),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Back to my stage'),
            ),
          ],
        );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
          child: body,
        ),
      ),
    );
  }
}

class _RecordingBanner extends StatefulWidget {
  const _RecordingBanner();

  @override
  State<_RecordingBanner> createState() => _RecordingBannerState();
}

class _RecordingBannerState extends State<_RecordingBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.35,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: JamJotColors.recording, width: 2),
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: _pulse,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: JamJotColors.recording,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Listening & recording — tap "I\'m done" to stop',
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.emoji,
    required this.title,
    required this.body,
    required this.button,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String body;
  final String button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft)),
          const SizedBox(height: 20),
          FilledButton(onPressed: onTap, child: Text(button)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => GoRouter.of(context).go('/practice'),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}
