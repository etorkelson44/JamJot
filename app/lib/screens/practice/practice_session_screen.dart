import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';

import '../../services/sound_meter.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/dancing_note.dart';

enum _Phase { starting, practicing, saving, celebrate, micDenied, error }

class PracticeSessionScreen extends ConsumerStatefulWidget {
  const PracticeSessionScreen({super.key});

  @override
  ConsumerState<PracticeSessionScreen> createState() =>
      _PracticeSessionScreenState();
}

class _PracticeSessionScreenState
    extends ConsumerState<PracticeSessionScreen> {
  final _recorder = AudioRecorder();
  final _meter = SoundMeter();

  _Phase _phase = _Phase.starting;
  String? _sessionId;
  Map<String, dynamic>? _lesson;
  List<Map<String, dynamic>> _songs = [];

  /// Which song page is open (null = the song list).
  Map<String, dynamic>? _openSong;

  /// Is the mic actively recording right now (record button pressed)?
  bool _live = false;
  bool _recorderStarted = false;

  /// Sound-counted milliseconds, total and for the open song.
  int _soundMsTotal = 0;
  final Map<String, int> _soundMsBySong = {};
  final Set<String> _done = {};

  /// Loudness gate: room must be louder than this to count.
  static const _threshold = 0.035;

  /// Minimum real-sound time to finish a song (or bank extra practice).
  static const _minSongSeconds = 120;

  /// Sound-ms already paid out per song (so repeats earn on NEW time only).
  final Map<String, int> _bankedMs = {};
  bool _soundNow = false;
  Timer? _sampler;

  // Celebration numbers.
  int _minutes = 0;
  int _berries = 0;
  int _fans = 0;
  int _songsDone = 0;
  bool _goalMet = false;

  // Rewards collected song-by-song during this session.
  int _earnedBerries = 0;
  int _earnedFans = 0;

  int get _activeSeconds => _soundMsTotal ~/ 1000;
  int _songSeconds(String id) => (_soundMsBySong[id] ?? 0) ~/ 1000;

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
      final lesson = await ref
          .read(currentLessonProvider(student['id'] as String).future);
      _lesson = lesson;
      _songs = (lesson?['assignments'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final row = await JamJotBackend.client
          .from('sessions')
          .insert({'student_id': student['id']})
          .select()
          .single();
      _sessionId = row['id'] as String;
      setState(() => _phase = _Phase.practicing);
    } catch (_) {
      setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _toggleLive() async {
    if (_live) {
      // Stop: pause the recorder and the sound counting.
      _sampler?.cancel();
      try {
        await _recorder.pause();
      } catch (_) {}
      setState(() => _live = false);
      return;
    }
    // Start (or resume) listening & recording.
    try {
      if (!_recorderStarted) {
        final hasMic = await _recorder.hasPermission();
        final meterOk = await _meter.start();
        if (!hasMic || !meterOk) {
          setState(() => _phase = _Phase.micDenied);
          return;
        }
        await _recorder.start(const RecordConfig(), path: '');
        _recorderStarted = true;
      } else {
        try {
          await _recorder.resume();
        } catch (_) {}
      }
      // Sample the room 5x a second; count the slices that have sound.
      _sampler = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final loud = _meter.level > _threshold;
        if (loud) {
          _soundMsTotal += 200;
          final open = _openSong;
          if (open != null) {
            final id = open['id'] as String;
            _soundMsBySong[id] = (_soundMsBySong[id] ?? 0) + 200;
          }
        }
        if (mounted) setState(() => _soundNow = loud);
      });
      setState(() => _live = true);
    } catch (_) {
      setState(() => _phase = _Phase.error);
    }
  }

  /// Stop pressed on a song page: pause, confirm, rate, reward.
  Future<void> _stopAndMaybeFinishSong(Map<String, dynamic> song) async {
    final id = song['id'] as String;
    if (_live) await _toggleLive(); // pause the mic while we talk
    if (!mounted) return;

    // Not enough real sound yet? Encourage, don't finish.
    if (_songSeconds(id) < _minSongSeconds) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
            side: JamJotShape.border,
          ),
          title: const Text('Almost there!'),
          content: Text(
              'A song needs at least 2 minutes of real sound to finish — you are at ${_fmt(_songSeconds(id))} of 02:00. Keep going, you have got this!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('back'),
              child: const Text('Back to my songs'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('keep'),
              style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
              child: const Text('Keep practicing'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == 'keep') {
        await _toggleLive();
      } else if (choice == 'back') {
        setState(() => _openSong = null);
      }
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text('Done with ${song['title']}?'),
        content: Text(
            'You made ${_fmt(_songSeconds(id))} of real sound on this one. All finished, or keep going?'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop('keep'),
            child: const Text('Keep practicing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('done'),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text("I'm done!"),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'keep') {
      await _toggleLive(); // recording picks right back up
      return;
    }
    if (choice != 'done') return; // dismissed: stay paused on the song page

    final rating = await _askRating(song['title'] as String);
    if (!mounted) return;
    if (rating == null) {
      await _toggleLive();
      return;
    }
    await _completeSong(song, rating);
  }

  Future<String?> _askRating(String title) {
    Widget option(BuildContext context, String emoji, String label,
        String value, Color tint) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: tint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: JamJotColors.ink, width: 2),
          ),
          child: InkWell(
            onTap: () => Navigator.of(context).pop(value),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: const Text('How did that feel?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(context, '🌟', 'I got it down!', 'got_it',
                JamJotColors.marigoldTint),
            option(context, '👍', 'Getting there', 'getting_there',
                JamJotColors.blueberryTint),
            option(context, '💪', 'Still working on nailing it',
                'working_on_it', JamJotColors.plumTint),
          ],
        ),
      ),
    );
  }

  Future<void> _completeSong(Map<String, dynamic> song, String rating) async {
    final id = song['id'] as String;
    setState(() {
      _done.add(id);
      _openSong = null;
    });
    var berries = 0;
    var fans = 0;
    try {
      final seg = await JamJotBackend.client
          .from('session_segments')
          .insert({
            'session_id': _sessionId,
            'assignment_id': id,
            'kind': 'playing',
            'seconds': _songSeconds(id),
            'completed': true,
            'goal_results': {'self_rating': rating},
          })
          .select()
          .single();
      _bankedMs[id] = _soundMsBySong[id] ?? 0;
      final res = await JamJotBackend.client.functions.invoke('award-song',
          body: {
            'session_id': _sessionId,
            'assignment_id': id,
            'segment_id': seg['id'],
          });
      final data = res.data as Map<String, dynamic>? ?? {};
      berries = (data['berries'] as num?)?.toInt() ?? 0;
      fans = (data['fans'] as num?)?.toInt() ?? 0;
      _earnedBerries += berries;
      _earnedFans += fans;
    } catch (_) {/* rewards settle at session end if this hiccups */}
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text('🎉 ${song['title']} done!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (berries > 0)
              Text('🫐 +$berries berries',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            if (fans > 0)
              Text('🕶️ +$fans fans join your crowd!',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            if (berries == 0 && fans == 0)
              const Text('Saved! Your rewards tally up at the end.'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            child: const Text('Keep jamming'),
          ),
        ],
      ),
    );
  }

  /// Extra practice on an already-finished song: every fresh 2+ minutes of
  /// sound can be banked for bonus fans.
  Future<void> _bankExtra(Map<String, dynamic> song) async {
    final id = song['id'] as String;
    final extraMs = (_soundMsBySong[id] ?? 0) - (_bankedMs[id] ?? 0);
    final extraSeconds = extraMs ~/ 1000;
    if (extraSeconds < _minSongSeconds) return;
    if (_live) await _toggleLive();
    var fans = 0;
    try {
      final seg = await JamJotBackend.client
          .from('session_segments')
          .insert({
            'session_id': _sessionId,
            'assignment_id': id,
            'kind': 'playing',
            'seconds': extraSeconds,
            'completed': true,
            'goal_results': {'extra_practice': true},
          })
          .select()
          .single();
      _bankedMs[id] = _soundMsBySong[id] ?? 0;
      final res = await JamJotBackend.client.functions.invoke('award-song',
          body: {
            'session_id': _sessionId,
            'assignment_id': id,
            'segment_id': seg['id'],
          });
      final data = res.data as Map<String, dynamic>? ?? {};
      fans = (data['fans'] as num?)?.toInt() ?? 0;
      _earnedFans += fans;
    } catch (_) {}
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: const Text('🎉 Extra practice banked!'),
        content: Text(fans > 0
            ? '🕶️ +$fans bonus fans for coming back to this song!'
            : 'Saved! Your rewards tally up at the end.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            child: const Text('Keep jamming'),
          ),
        ],
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _finish() async {
    setState(() => _phase = _Phase.saving);
    _sampler?.cancel();
    try {
      if (_recorderStarted) await _recorder.stop();
    } catch (_) {}
    _meter.stop();
    try {
      await JamJotBackend.client.from('sessions').update({
        'ended_at': DateTime.now().toUtc().toIso8601String(),
        'total_seconds': _activeSeconds,
      }).eq('id', _sessionId!);
      final res = await JamJotBackend.client.functions
          .invoke('award-practice', body: {'session_id': _sessionId});
      final data = res.data as Map<String, dynamic>? ?? {};
      setState(() {
        _minutes = (data['minutes'] as num?)?.toInt() ?? _activeSeconds ~/ 60;
        _berries =
            ((data['berries'] as num?)?.toInt() ?? 0) + _earnedBerries;
        _fans = _earnedFans;
        _songsDone = _done.length;
        _goalMet = data['goal_met'] == true;
        _phase = _Phase.celebrate;
      });
    } catch (_) {
      setState(() {
        _minutes = _activeSeconds ~/ 60;
        _berries = _earnedBerries;
        _fans = _earnedFans;
        _songsDone = _done.length;
        _goalMet = false;
        _phase = _Phase.celebrate;
      });
    }
  }

  @override
  void dispose() {
    _sampler?.cancel();
    _recorder.dispose();
    _meter.stop();
    super.dispose();
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final student = ref.watch(activeStudentProvider);

    Widget body;
    switch (_phase) {
      case _Phase.starting:
      case _Phase.saving:
        body = const Center(child: CircularProgressIndicator());
      case _Phase.micDenied:
        body = _Message(
          emoji: '🎤',
          title: 'JamJot needs to hear you!',
          body:
              'Practice only counts when it is really heard. Please allow the microphone in your browser and try again.',
          button: 'Try again',
          onTap: () => setState(() => _phase = _Phase.practicing),
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
      case _Phase.practicing:
        body = _openSong == null ? _buildSongList(text) : _buildSongPage(text);
      case _Phase.celebrate:
        body = _buildCelebrate(text);
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: body,
        ),
      ),
    );
  }

  Widget _goalsHeader(TextTheme text) {
    final student = ref.watch(activeStudentProvider);
    final goalDays = (_lesson?['goal_days'] as num?)?.toInt() ?? 4;
    final goalMinutes = (_lesson?['goal_minutes'] as num?)?.toInt() ?? 15;
    final progress = student == null
        ? null
        : ref
            .watch(weeklyProgressProvider(student['id'] as String))
            .valueOrNull;
    final days = progress?['days'] ?? 0;
    final baseToday = progress?['today_minutes'] ?? 0;
    final todayMinutes = baseToday + _activeSeconds ~/ 60;
    Widget chip(String label, bool met) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: met ? JamJotColors.blueberryTint : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: JamJotColors.ink, width: 1.5),
          ),
          child: Text(label,
              style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
        );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        chip('📅 This week: $days/$goalDays days', days >= goalDays),
        chip('⏱️ Today: $todayMinutes/$goalMinutes min',
            todayMinutes >= goalMinutes),
      ],
    );
  }

  Widget _recordButton() {
    return FilledButton(
      onPressed: _toggleLive,
      style: FilledButton.styleFrom(
        backgroundColor:
            _live ? JamJotColors.recording : JamJotColors.ink,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_live ? Icons.stop : Icons.fiber_manual_record,
              color: _live ? Colors.white : JamJotColors.recording),
          const SizedBox(width: 8),
          Text(_live ? 'Stop' : 'Record'),
        ],
      ),
    );
  }

  Widget _liveBanner(TextTheme text) {
    if (!_live) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JamJotColors.recording, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _soundNow
                  ? JamJotColors.recording
                  : JamJotColors.outline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _soundNow
                  ? 'Listening & recording — I hear you!'
                  : 'Listening & recording — waiting for sound…',
              style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongList(TextTheme text) {
    return Column(
      children: [
        _goalsHeader(text),
        const SizedBox(height: 10),
        _liveBanner(text),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DancingNote(size: 56),
            const SizedBox(width: 12),
            Text(_fmt(_activeSeconds),
                style: text.displaySmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('of real\nsound', style: text.labelSmall),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _songs.isEmpty
              ? Center(
                  child: Text(
                    'No songs assigned yet — free play!\nTap Record and make some music; sound minutes still count.',
                    textAlign: TextAlign.center,
                    style: text.titleSmall
                        ?.copyWith(color: JamJotColors.inkSoft),
                  ),
                )
              : Builder(builder: (context) {
                  final nextUp = _songs
                      .where((s) => !_done.contains(s['id']))
                      .toList();
                  final practiced = _songs
                      .where((s) => _done.contains(s['id']))
                      .toList();
                  Widget header(String label) => Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(label,
                            style: text.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      );
                  return ListView(
                    children: [
                      if (nextUp.isNotEmpty) header('🎵 Next up'),
                      for (final song in nextUp) ...[
                        _SongTile(
                          title: song['title'] as String,
                          note: song['song_note'] as String? ?? '',
                          minutes:
                              (song['suggested_minutes'] as num?)?.toInt(),
                          spentSeconds: _songSeconds(song['id'] as String),
                          done: false,
                          onTap: () => setState(() => _openSong = song),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (practiced.isNotEmpty) header('✅ Practiced'),
                      for (final song in practiced) ...[
                        _SongTile(
                          title: song['title'] as String,
                          note: song['song_note'] as String? ?? '',
                          minutes:
                              (song['suggested_minutes'] as num?)?.toInt(),
                          spentSeconds: _songSeconds(song['id'] as String),
                          done: true,
                          onTap: () => setState(() => _openSong = song),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                }),
        ),
        const SizedBox(height: 8),
        _recordButton(),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _finish,
          child: const Text("I'm done practicing"),
        ),
      ],
    );
  }

  Widget _buildSongPage(TextTheme text) {
    final song = _openSong!;
    final id = song['id'] as String;
    final target = (song['suggested_minutes'] as num?)?.toInt();
    final note = song['song_note'] as String? ?? '';
    final lessonNote = _lesson?['lesson_note'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _openSong = null),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(song['title'] as String,
                  style: text.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Text(
              target == null
                  ? _fmt(_songSeconds(id))
                  : '${_fmt(_songSeconds(id))} / $target min',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        _liveBanner(text),
        Expanded(
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: JamJotColors.outline, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎼', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 6),
                Text(
                  'Sheet music shows here once\nscores are uploaded',
                  textAlign: TextAlign.center,
                  style:
                      text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
                ),
              ],
            ),
          ),
        ),
        if (note.isNotEmpty || lessonNote.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JamJotColors.marigoldTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: JamJotColors.ink, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.isNotEmpty)
                  Text('🎵 $note',
                      style: text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                if (lessonNote.isNotEmpty)
                  Text('📝 $lessonNote', style: text.bodySmall),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (_done.contains(id)) ...[
          // Already finished — fresh 2-minute chunks earn bonus fans.
          _recordButton(),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final extraSec =
                ((_soundMsBySong[id] ?? 0) - (_bankedMs[id] ?? 0)) ~/ 1000;
            if (extraSec >= _minSongSeconds) {
              return OutlinedButton(
                onPressed: () => _bankExtra(song),
                child: const Text('Bank extra practice (+5 fans!)'),
              );
            }
            return Text(
              'Finished ✅ — ${_fmt(extraSec)} / 02:00 of extra practice toward bonus fans',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
            );
          }),
        ] else if (_live) ...[
          FilledButton(
            onPressed: () => _stopAndMaybeFinishSong(song),
            style:
                FilledButton.styleFrom(backgroundColor: JamJotColors.recording),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.stop, color: Colors.white),
                SizedBox(width: 8),
                Text('Stop'),
              ],
            ),
          ),
        ] else ...[
          _recordButton(),
          if (_songSeconds(id) > 0) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _stopAndMaybeFinishSong(song),
              child: const Text('Done with this song'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildCelebrate(TextTheme text) {
    return Column(
      children: [
        const Spacer(),
        const Text('🎉', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 8),
        Text(
            'You made $_minutes minute${_minutes == 1 ? '' : 's'} of real music!',
            textAlign: TextAlign.center,
            style:
                text.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        if (_songsDone > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('$_songsDone song${_songsDone == 1 ? '' : 's'} finished',
                style:
                    text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
        if (_fans > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: JamJotColors.marigoldTint,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: JamJotColors.ink, width: 2),
              ),
              child: Text('🕶️ +$_fans new fans in your crowd!',
                  style:
                      text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
        if (_berries > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: JamJotColors.plumTint,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: JamJotColors.ink, width: 2),
            ),
            child: Text('🫐 +$_berries berries in your jar!',
                style:
                    text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (_goalMet)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Session goal reached — amazing!',
                  style: text.titleSmall?.copyWith(color: JamJotColors.leaf)),
            ),
        ] else ...[
          Text(
            'The session goal is 15 sound-minutes — a little more next time and the berries start rolling in!',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
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
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.title,
    required this.note,
    required this.minutes,
    required this.spentSeconds,
    required this.done,
    required this.onTap,
  });

  final String title;
  final String note;
  final int? minutes;
  final int spentSeconds;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final spentMin = spentSeconds ~/ 60;
    return Material(
      color: done ? JamJotColors.blueberryTint : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: JamJotColors.ink, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(done ? '✅' : '🎼', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            decoration:
                                done ? TextDecoration.lineThrough : null)),
                    if (note.isNotEmpty)
                      Text(note,
                          style: text.bodySmall
                              ?.copyWith(color: JamJotColors.inkSoft)),
                  ],
                ),
              ),
              Text(
                minutes == null
                    ? (spentMin > 0 ? '$spentMin min' : '')
                    : '$spentMin/$minutes min',
                style:
                    text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (!done) const Icon(Icons.chevron_right),
            ],
          ),
        ),
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
