import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../services/sound_meter.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/dancing_note.dart';
import '../../widgets/score_frame.dart';

enum _Phase { starting, practicing, saving, celebrate, micDenied, error, closed }

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
  bool _meterStarted = false;

  /// Uploaded clips not yet attached to a saved song summary,
  /// keyed by song id ('_freeplay' for no-song recording).
  /// Each entry: {path, at, wall_seconds, sound_seconds}.
  final Map<String, List<Map<String, dynamic>>> _pendingClips = {};

  /// Stamps for the clip currently rolling.
  DateTime? _clipStartedAt;
  int _clipStartSoundMs = 0;

  /// Signed sheet-music links, fetched once per song.
  final Map<String, Future<String?>> _scoreUrls = {};

  Future<String?> _scoreUrlFor(Map<String, dynamic> song) {
    final id = song['id'] as String;
    return _scoreUrls[id] ??= () async {
      final scoreId = song['score_id'] as String?;
      if (scoreId == null) return null;
      try {
        final score = await JamJotBackend.client
            .from('scores')
            .select('original_path')
            .eq('id', scoreId)
            .maybeSingle();
        final path = score?['original_path'] as String?;
        if (path == null) return null;
        return JamJotBackend.client.storage
            .from('scores')
            .createSignedUrl(path, 3600 * 6);
      } catch (_) {
        return null;
      }
    }();
  }

  /// What each finished song earned & how the kid rated it (for the list).
  final Map<String, String> _ratings = {};
  final Map<String, String> _awardsLabel = {};

  /// Sound-counted milliseconds, total and for the open song.
  int _soundMsTotal = 0;
  final Map<String, int> _soundMsBySong = {};
  final Set<String> _done = {};

  /// Wall-clock recording time (sound or silence) per song & banked markers.
  final Map<String, int> _wallMsBySong = {};
  final Map<String, int> _bankedWallMs = {};

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
      // The night-before-lesson cutoff: once the teacher's sheet is
      // finalized, this week's practice is closed.
      final cutoff = await ref
          .read(practiceCutoffProvider(student['id'] as String).future);
      if (cutoff != null) {
        if (mounted) setState(() => _phase = _Phase.closed);
        return;
      }
      final lesson = await ref
          .read(currentLessonProvider(student['id'] as String).future);
      _lesson = lesson;
      _songs = (lesson?['assignments'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      // Coming back on the same day? Reopen today's session and keep adding.
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final existing = await JamJotBackend.client
          .from('sessions')
          .select('*, session_segments(*)')
          .eq('student_id', student['id'])
          .gte('started_at', dayStart.toUtc().toIso8601String())
          .order('started_at', ascending: false)
          .limit(1);
      if (existing.isNotEmpty) {
        // A session from earlier today: show its progress; recording
        // again reopens it (see _ensureSession).
        final session = existing.first;
        _sessionId = session['id'] as String;
        _sessionSaved = session['ended_at'] != null;
        var segmentMs = 0;
        for (final seg in (session['session_segments'] as List? ?? [])
            .cast<Map<String, dynamic>>()) {
          final aid = seg['assignment_id'] as String?;
          final ms = (((seg['seconds'] as num?)?.toInt()) ?? 0) * 1000;
          segmentMs += ms;
          if (aid != null) {
            _soundMsBySong[aid] = (_soundMsBySong[aid] ?? 0) + ms;
            _bankedMs[aid] = (_bankedMs[aid] ?? 0) + ms;
            final wallMs =
                (((seg['wall_seconds'] as num?)?.toInt()) ?? 0) * 1000;
            _wallMsBySong[aid] = (_wallMsBySong[aid] ?? 0) + wallMs;
            _bankedWallMs[aid] = (_bankedWallMs[aid] ?? 0) + wallMs;
            final rating =
                (seg['goal_results'] as Map?)?['self_rating'] as String?;
            if (seg['completed'] == true && rating != null) {
              _done.add(aid);
              _ratings[aid] = rating;
            }
          }
        }
        final storedMs =
            (((session['total_seconds'] as num?)?.toInt()) ?? 0) * 1000;
        _soundMsTotal = storedMs > segmentMs ? storedMs : segmentMs;
      }
      // No session row is created yet — that happens the moment a song's
      // Record button is pressed for the first time (_ensureSession).
      setState(() => _phase = _Phase.practicing);
    } catch (_) {
      setState(() => _phase = _Phase.error);
    }
  }

  /// True when today's session exists but was already saved once.
  bool _sessionSaved = false;

  /// Creates (or reopens) today's session the moment recording begins.
  Future<void> _ensureSession() async {
    final student = ref.read(activeStudentProvider);
    if (student == null) return;
    if (_sessionId == null) {
      final row = await JamJotBackend.client
          .from('sessions')
          .insert({'student_id': student['id']})
          .select()
          .single();
      _sessionId = row['id'] as String;
    } else if (_sessionSaved) {
      await JamJotBackend.client
          .from('sessions')
          .update({'ended_at': null}).eq('id', _sessionId!);
      _sessionSaved = false;
    }
  }

  Future<void> _toggleLive() async {
    if (_live) {
      // Stop: close out this clip and upload it to its song.
      _sampler?.cancel();
      setState(() => _live = false);
      try {
        final url = await _recorder.stop();
        if (url != null) await _uploadClip(url);
      } catch (_) {}
      return;
    }
    // Start listening & recording a fresh clip.
    try {
      final hasMic = await _recorder.hasPermission();
      if (!_meterStarted) {
        final meterOk = await _meter.start();
        if (!hasMic || !meterOk) {
          setState(() => _phase = _Phase.micDenied);
          return;
        }
        _meterStarted = true;
      } else if (!hasMic) {
        setState(() => _phase = _Phase.micDenied);
        return;
      }
      await _ensureSession();
      await _recorder.start(const RecordConfig(), path: '');
      _clipStartedAt = DateTime.now();
      _clipStartSoundMs = _soundMsTotal;
      // Sample the room 5x a second; count the slices that have sound.
      _sampler = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final loud = _meter.level > _threshold;
        final open = _openSong;
        if (open != null) {
          final id = open['id'] as String;
          _wallMsBySong[id] = (_wallMsBySong[id] ?? 0) + 200;
        }
        if (loud) {
          _soundMsTotal += 200;
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

  /// Uploads one finished clip and files it under the song it belongs to,
  /// stamped with when it started and both of its times.
  Future<void> _uploadClip(String blobUrl) async {
    final student = ref.read(activeStudentProvider);
    if (student == null || _sessionId == null) return;
    final startedAt = _clipStartedAt ?? DateTime.now();
    final wallSeconds = DateTime.now().difference(startedAt).inSeconds;
    final soundSeconds = (_soundMsTotal - _clipStartSoundMs) ~/ 1000;
    try {
      final bytes = (await http.get(Uri.parse(blobUrl))).bodyBytes;
      if (bytes.isEmpty) return;
      final songKey = (_openSong?['id'] as String?) ?? '_freeplay';
      final path =
          '${student['id']}/$_sessionId/$songKey-${startedAt.millisecondsSinceEpoch}.webm';
      await JamJotBackend.client.storage.from('recordings').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'audio/webm'),
          );
      (_pendingClips[songKey] ??= []).add({
        'path': path,
        'at': startedAt.toUtc().toIso8601String(),
        'wall_seconds': wallSeconds,
        'sound_seconds': soundSeconds,
      });
    } catch (_) {/* stats still count even if a clip fails to upload */}
  }

  List<Map<String, dynamic>> _takeClips(String songKey) {
    return _pendingClips.remove(songKey) ?? [];
  }

  /// The two clip columns a segment row carries.
  Map<String, dynamic> _clipFields(List<Map<String, dynamic>> clips) => {
        'audio_paths': [for (final c in clips) c['path']],
        'audio_clips': clips,
      };

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
            ..._clipFields(_takeClips(id)),
            'wall_seconds':
                ((_wallMsBySong[id] ?? 0) - (_bankedWallMs[id] ?? 0)) ~/ 1000,
          })
          .select()
          .single();
      _bankedMs[id] = _soundMsBySong[id] ?? 0;
      _bankedWallMs[id] = _wallMsBySong[id] ?? 0;
      _ratings[id] = rating;
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
      _awardsLabel[id] = '🫐+$berries 🕶️+$fans';
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
            ..._clipFields(_takeClips(id)),
            'wall_seconds':
                ((_wallMsBySong[id] ?? 0) - (_bankedWallMs[id] ?? 0)) ~/ 1000,
          })
          .select()
          .single();
      _bankedMs[id] = _soundMsBySong[id] ?? 0;
      _bankedWallMs[id] = _wallMsBySong[id] ?? 0;
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
    // Close any clip still rolling, so it gets uploaded to its song.
    if (_live) await _toggleLive();
    setState(() => _phase = _Phase.saving);
    _sampler?.cancel();
    _meter.stop();
    _meterStarted = false;

    try {
      // Unfinished songs keep their progress & clips as in-progress summaries.
      for (final song in _songs) {
        final id = song['id'] as String;
        if (_done.contains(id)) continue;
        final freshSeconds =
            ((_soundMsBySong[id] ?? 0) - (_bankedMs[id] ?? 0)) ~/ 1000;
        final clips = _takeClips(id);
        if (freshSeconds < 5 && clips.isEmpty) continue;
        await JamJotBackend.client.from('session_segments').insert({
          'session_id': _sessionId,
          'assignment_id': id,
          'kind': 'playing',
          'seconds': freshSeconds,
          'completed': false,
          ..._clipFields(clips),
          'wall_seconds':
              ((_wallMsBySong[id] ?? 0) - (_bankedWallMs[id] ?? 0)) ~/ 1000,
        });
        _bankedMs[id] = _soundMsBySong[id] ?? 0;
        _bankedWallMs[id] = _wallMsBySong[id] ?? 0;
      }
      // Free play (recording with no song open) is kept too.
      final freeClips = _takeClips('_freeplay');
      if (freeClips.isNotEmpty) {
        await JamJotBackend.client.from('session_segments').insert({
          'session_id': _sessionId,
          'kind': 'free_play',
          'seconds': 0,
          'completed': false,
          ..._clipFields(freeClips),
        });
      }

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
        _sessionSaved = true;
      });
    } catch (_) {
      setState(() {
        _minutes = _activeSeconds ~/ 60;
        _berries = _earnedBerries;
        _fans = _earnedFans;
        _songsDone = _done.length;
        _goalMet = false;
        _phase = _Phase.celebrate;
        _sessionSaved = true;
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
      case _Phase.closed:
        body = Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '🌙 This week\'s practice is all tucked in — your teacher is preparing your lesson sheet. See you at your lesson!',
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
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

  Widget _lessonScheduleCards(TextTheme text) {
    final student = ref.watch(activeStudentProvider);
    if (student == null) return const SizedBox.shrink();
    final sched = ref
        .watch(lessonScheduleProvider(student['id'] as String))
        .valueOrNull;
    Widget card(String emoji, String label, Map<String, dynamic>? ev) {
      final teacher =
          (ev?['teachers'] as Map?)?['display_name'] as String?;
      final when = ev == null
          ? null
          : DateFormat('EEE, MMM d • h:mm a')
              .format(DateTime.parse(ev['starts_at'] as String).toLocal());
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: JamJotColors.ink, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$emoji $label',
                  style: text.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                ev == null
                    ? 'Not scheduled yet'
                    : '$when${teacher != null ? '\nwith $teacher' : ''}',
                style: text.labelSmall
                    ?.copyWith(color: JamJotColors.inkSoft),
              ),
            ],
          ),
        ),
      );
    }

    return Row(children: [
      card('🎒', 'Last lesson', sched?['last']),
      const SizedBox(width: 8),
      card('📅', 'Next lesson', sched?['next']),
    ]);
  }

  Widget _buildSongList(TextTheme text) {
    return Column(
      children: [
        _lessonScheduleCards(text),
        const SizedBox(height: 10),
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
                    'No songs assigned yet!\nAsk your grown-up or teacher to add this week\'s songs.',
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
                          note: [
                            if (song['source'] != null)
                              '🎻 ${song['source']}',
                            if ((song['song_note'] as String? ?? '')
                                .isNotEmpty)
                              song['song_note'] as String,
                          ].join(' • '),
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
                        Builder(builder: (context) {
                          final id = song['id'] as String;
                          const ratingLabels = {
                            'got_it': '🌟 Got it down',
                            'getting_there': '👍 Getting there',
                            'working_on_it': '💪 Working on it',
                          };
                          final parts = [
                            if (_ratings[id] != null)
                              ratingLabels[_ratings[id]] ?? '',
                            if (_awardsLabel[id] != null) _awardsLabel[id]!,
                          ];
                          return _SongTile(
                            title: song['title'] as String,
                            note: parts.isEmpty
                                ? (song['song_note'] as String? ?? '')
                                : parts.join(' • '),
                            minutes:
                                (song['suggested_minutes'] as num?)?.toInt(),
                            spentSeconds: _songSeconds(id),
                            done: true,
                            onTap: () => setState(() => _openSong = song),
                          );
                        }),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                }),
        ),
        const SizedBox(height: 8),
        // Recording lives inside each song — tap one to start.
        if (_sessionId != null && !_sessionSaved)
          FilledButton(
            onPressed: _finish,
            child: const Text('Finish & save practice session'),
          )
        else if (_sessionSaved)
          Text(
            'Today\'s practice is saved — tap any song to add more before midnight. ✅',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
          )
        else
          Text(
            'Tap a song to see its music and start recording. 🎵',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  target == null
                      ? _fmt(_songSeconds(id))
                      : '${_fmt(_songSeconds(id))} / $target min',
                  style:
                      text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${_fmt((_wallMsBySong[id] ?? 0) ~/ 1000)} recorded',
                  style:
                      text.labelSmall?.copyWith(color: JamJotColors.inkSoft),
                ),
              ],
            ),
          ],
        ),
        _liveBanner(text),
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: JamJotColors.outline, width: 2),
            ),
            child: FutureBuilder<String?>(
              future: _scoreUrlFor(song),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final url = snap.data;
                if (url == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🎼', style: TextStyle(fontSize: 44)),
                        const SizedBox(height: 6),
                        Text(
                          'No sheet music attached to this song yet',
                          textAlign: TextAlign.center,
                          style: text.bodySmall
                              ?.copyWith(color: JamJotColors.inkSoft),
                        ),
                      ],
                    ),
                  );
                }
                final lower = url.split('?').first.toLowerCase();
                final isImage = lower.endsWith('.png') ||
                    lower.endsWith('.jpg') ||
                    lower.endsWith('.jpeg');
                if (isImage) {
                  return InteractiveViewer(
                    maxScale: 5,
                    child: Center(child: Image.network(url)),
                  );
                }
                return buildScoreFrame(url);
              },
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
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => setState(() => _phase = _Phase.practicing),
          child: const Text('Keep practicing today'),
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
