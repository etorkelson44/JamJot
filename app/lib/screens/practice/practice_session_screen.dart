import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../services/sound_effects.dart';
import '../../services/recording_file.dart';
import '../../services/practice_navigation.dart';
import '../../services/unload_guard.dart';
import '../history/practice_history_screen.dart';
import '../lesson/lesson_sheet_screen.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/coin_pouch.dart';
import '../../widgets/dancing_note.dart';
import '../../widgets/fan_stage.dart';
import '../../widgets/score_frame.dart';
import '../../widgets/stickers.dart';

final practiceRecorderProvider =
    Provider<AudioRecorder>((ref) => AudioRecorder());

enum _Phase {
  starting,
  practicing,
  saving,
  celebrate,
  micDenied,
  error,
  closed
}

class PracticeSessionScreen extends ConsumerStatefulWidget {
  const PracticeSessionScreen({super.key});

  @override
  ConsumerState<PracticeSessionScreen> createState() =>
      _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends ConsumerState<PracticeSessionScreen>
    with WidgetsBindingObserver {
  late final AudioRecorder _recorder;
  bool _busy = false;
  bool _deciding = false;
  late final PracticeExitGuard _exitGuard;
  late final Future<bool> Function() _exitHandler;
  bool _dialogOpen = false;
  bool _sampling = false;
  final Stopwatch _clipClock = Stopwatch();
  int _sampleAt = 0;
  String? _clipSongKey;
  String? _clipId;
  String? _notice;

  _Phase _phase = _Phase.starting;
  String? _sessionId;
  Map<String, dynamic>? _lesson;
  List<Map<String, dynamic>> _songs = [];

  /// Which song page is open (null = the song list).
  Map<String, dynamic>? _openSong;

  /// Is the mic actively recording right now (record button pressed)?
  bool _live = false;

  /// Uploaded clips not yet attached to a saved song summary,
  /// keyed by song id ('_freeplay' for no-song recording).
  /// Each entry: {path, at, wall_seconds, sound_seconds}.
  final Map<String, List<Map<String, dynamic>>> _pendingClips = {};
  final Map<String, String> _segmentIds = {};

  /// Stamps for the clip currently rolling.
  DateTime? _clipStartedAt;
  int _clipStartSoundMs = 0;

  /// Music-vs-notes balance on the song page (toggled by the kid).
  bool _scoreSmall = false;

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
        return await JamJotBackend.client.storage
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
  static const _thresholdDb = -40.0;

  /// Minimum real-sound time to finish a song (or bank extra practice).
  static const _minSongSeconds = 60;

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
    _recorder = ref.read(practiceRecorderProvider);
    WidgetsBinding.instance.addObserver(this);
    _exitGuard = ref.read(practiceExitGuardProvider);
    _exitHandler = _confirmLeavePractice;
    _exitGuard.beforeLeave = _exitHandler;
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
      final lesson =
          await ref.read(currentLessonProvider(student['id'] as String).future);
      _lesson = lesson;
      _songs =
          (lesson?['assignments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      // Coming back on the same day? Reopen today's session and keep adding.
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final existing = await JamJotBackend.client
          .from('sessions')
          .select('*, session_segments(*)')
          .eq('student_id', student['id'])
          .eq('source', 'app')
          .isFilter('manual_override_seconds', null)
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
    } catch (e) {
      _lastError = e.toString();
      setState(() => _phase = _Phase.error);
    }
  }

  /// What actually went wrong, shown on the error screen so it can be fixed.
  String? _lastError;

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
      if (mounted) popSticker(context, 'lets_jam', ms: 1400);
    } else if (_sessionSaved) {
      await JamJotBackend.client
          .from('sessions')
          .update({'ended_at': null}).eq('id', _sessionId!);
      _sessionSaved = false;
    }
  }

  void _showProblem(String message) {
    if (!mounted) return;
    setState(() => _notice = message);
  }

  Future<void> _toggleLive() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_live) {
        await _stopClip();
      } else {
        if (!await _recorder.hasPermission()) {
          if (mounted) setState(() => _phase = _Phase.micDenied);
          return;
        }
        await _retryUploads();
        await _ensureSession();
        _clipId = const Uuid().v4();
        _clipSongKey = (_openSong?['id'] as String?) ?? '_freeplay';
        // WAV is supported by the recorder on Safari, Chrome, iOS and Android.
        // Meter the recorder's own input instead of opening a second microphone.
        await _recorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: 22050,
              numChannels: 1,
              echoCancel: false,
              noiseSuppress: false,
              autoGain: false,
            ),
            path: await recordingPath(_clipId!));
        if (await _recorder.isPaused()) await _recorder.resume();
        _clipStartedAt = DateTime.now();
        _clipStartSoundMs = _soundMsTotal;
        _sampleAt = 0;
        _clipClock
          ..reset()
          ..start();
        _sampler = Timer.periodic(const Duration(milliseconds: 200), (_) async {
          if (_sampling || !_live) return;
          _sampling = true;
          try {
            final amplitude = await _recorder.getAmplitude();
            if (!_live || !mounted) return;
            final elapsed = _clipClock.elapsedMilliseconds;
            final delta = (elapsed - _sampleAt).clamp(0, 500).toInt();
            _sampleAt = elapsed;
            final loud =
                amplitude.current.isFinite && amplitude.current > _thresholdDb;
            final id = _clipSongKey;
            if (id != null && id != '_freeplay') {
              _wallMsBySong[id] = (_wallMsBySong[id] ?? 0) + delta;
            }
            if (loud) {
              _soundMsTotal += delta;
              if (id != null && id != '_freeplay') {
                _soundMsBySong[id] = (_soundMsBySong[id] ?? 0) + delta;
              }
            }
            setState(() => _soundNow = loud);
          } catch (_) {
            _showProblem(
                'The microphone level could not be read. Stop and try recording again.');
          } finally {
            _sampling = false;
          }
        });
        setUnloadGuard(true);
        if (mounted) {
          setState(() {
            _live = true;
            _notice = null;
          });
        }
      }
    } catch (_) {
      _showProblem(
          'The recording could not be started or saved. Your progress is still here. Try again before leaving this page.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopClip({bool discard = false}) async {
    _sampler?.cancel();
    _clipClock.stop();
    final key = _clipSongKey ?? '_freeplay';
    if (discard) {
      await _recorder.cancel();
      final removed = _soundMsTotal - _clipStartSoundMs;
      _soundMsTotal -= removed;
      if (key != '_freeplay') {
        _soundMsBySong[key] =
            ((_soundMsBySong[key] ?? 0) - removed).clamp(0, 1 << 40);
        _wallMsBySong[key] =
            ((_wallMsBySong[key] ?? 0) - _sampleAt).clamp(0, 1 << 40);
      }
    } else {
      final local = await _recorder.stop();
      if (local == null) throw StateError('No recording was returned.');
      final student = ref.read(activeStudentProvider)!;
      (_pendingClips[key] ??= []).add({
        'path': '${student['id']}/$_sessionId/$key-$_clipId.wav',
        'local_path': local,
        'at': _clipStartedAt!.toUtc().toIso8601String(),
        'wall_seconds': _clipClock.elapsed.inSeconds,
        'sound_seconds': (_soundMsTotal - _clipStartSoundMs) ~/ 1000,
      });
    }
    if (mounted) {
      setState(() {
        _live = false;
        _soundNow = false;
      });
    }
    if (!discard) await _retryUploads();
  }

  Future<void> _retryUploads() async {
    for (final clips in _pendingClips.values) {
      for (final clip in clips) {
        final local = clip['local_path'] as String?;
        if (local == null) continue;
        final bytes = await readRecording(local);
        if (bytes.isEmpty) throw StateError('The recording is empty.');
        await JamJotBackend.client.storage
            .from('recordings')
            .uploadBinary(
              clip['path'] as String,
              bytes,
              fileOptions: const FileOptions(contentType: 'audio/wav'),
            )
            .catchError((Object error) {
          // A timed-out upload may already have succeeded. Keep its stable path.
          if (error.toString().contains('Duplicate') ||
              error.toString().contains('already exists')) {
            return clip['path'] as String;
          }
          throw error;
        });
        clip.remove('local_path');
        await releaseRecording(local);
      }
    }
  }

  Future<T?> _practiceDialog<T>({required WidgetBuilder builder}) async {
    if (mounted) setState(() => _dialogOpen = true);
    try {
      return await showDialog<T>(context: context, builder: builder);
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  Future<void> _leaveSong() async {
    if (_busy) return;
    if (_live) await _toggleLive();
    if (_live || !mounted) return;
    await _stopAndMaybeFinishSong(_openSong!);
  }

  List<Map<String, dynamic>> _takeClips(String songKey) {
    return _pendingClips[songKey] ?? [];
  }

  /// The two clip columns a segment row carries.
  Map<String, dynamic> _clipFields(List<Map<String, dynamic>> clips) => {
        'audio_paths': [for (final c in clips) c['path']],
        'audio_clips': clips,
      };

  /// Stop pressed on a song page: pause, confirm, rate, reward.
  Future<void> _stopAndMaybeFinishSong(Map<String, dynamic> song) async {
    if (_deciding || _busy) return;
    _deciding = true;
    try {
      await _songDecision(song);
    } finally {
      _deciding = false;
    }
  }

  Future<void> _songDecision(Map<String, dynamic> song) async {
    final id = song['id'] as String;
    if (_live) await _toggleLive(); // pause the mic while we talk
    if (!mounted || _live) return;
    try {
      await _retryUploads();
    } catch (_) {
      _showProblem(
          'Your recording is waiting to upload. Try again before leaving.');
      return;
    }

    // Not enough real sound yet? Encourage, don't finish.
    if (_songSeconds(id) < _minSongSeconds) {
      final choice = await _practiceDialog<String>(
        builder: (context) => AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
            side: JamJotShape.border,
          ),
          title: const Text('Almost there!'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const StickerBadge('green_berry', size: 92),
            const SizedBox(height: 8),
            Text(
                'A song needs at least 1 minute of real sound to finish — you are at ${_fmt(_songSeconds(id))} of 01:00. Keep going, you have got this!'),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              child: const Text('Discard this take & return to songs'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('back'),
              child: const Text('Keep progress & return to songs'),
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
      } else if (choice == 'discard') {
        await _discardPendingTake(id);
        if (mounted) setState(() => _openSong = null);
      } else if (choice == 'back') {
        setState(() => _openSong = null);
      }
      return;
    }

    final choice = await _practiceDialog<String>(
      builder: (context) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text('Done with ${song['title']}?'),
        content: Text(
            'You made ${_fmt(_songSeconds(id))} of real sound toward your ${_suggestedMinutes(song)} minute goal. ${_songSeconds(id) < _suggestedMinutes(song) * 60 ? 'A little more practice will help you reach it! You can also save and move on.' : 'You reached your minutes goal! Ready to save?'}'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop('keep'),
            child: const Text('Keep practicing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('done'),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Save & move on'),
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
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return _practiceDialog<String>(
      builder: (context) => AlertDialog(
        scrollable: true,
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
    if (_busy) return;
    setState(() => _busy = true);
    var saved = false;
    var berries = 0;
    var fans = 0;
    try {
      await JamJotBackend.client
          .from('session_segments')
          .upsert({
            'id': _segmentIds.putIfAbsent(id, () => const Uuid().v4()),
            'session_id': _sessionId,
            'assignment_id': id,
            'kind': 'playing',
            'seconds':
                ((_soundMsBySong[id] ?? 0) - (_bankedMs[id] ?? 0)) ~/ 1000,
            'completed': true,
            'goal_results': {'self_rating': rating},
            ..._clipFields(_takeClips(id)),
            'wall_seconds':
                ((_wallMsBySong[id] ?? 0) - (_bankedWallMs[id] ?? 0)) ~/ 1000,
          })
          .select()
          .single();
      _segmentIds.remove(id);
      _pendingClips.remove(id);
      _bankedMs[id] = _soundMsBySong[id] ?? 0;
      _bankedWallMs[id] = _wallMsBySong[id] ?? 0;
      saved = true;
      _done.add(id);
      _openSong = null;
      _ratings[id] = rating;
      await JamJotBackend.client
          .from('sessions')
          .update({'total_seconds': _activeSeconds}).eq('id', _sessionId!);
      final data = Map<String, dynamic>.from(await JamJotBackend.client.rpc(
          'settle_practice_session',
          params: {'p_session_id': _sessionId}));
      berries = (data['berries'] as num?)?.toInt() ?? 0;
      fans = (data['fans'] as num?)?.toInt() ?? 0;
      _earnedBerries += berries;
      _earnedFans += fans;
      _awardsLabel[id] = '🪙+$berries 🕶️+$fans';
      if (berries > 0) playSound('coin');
      if (fans > 0) playSound('cheer');
      final sid = _lesson?['student_id'] as String? ??
          ref.read(activeStudentProvider)?['id'] as String?;
      if (sid != null) {
        ref.invalidate(berryBalanceProvider(sid));
        ref.invalidate(fanTotalProvider(sid));
        ref.invalidate(weeklyFansProvider(sid));
      }
      if (rating == 'working_on_it' && mounted) {
        popSticker(context, randomOf(keepGoingStickers), ms: 1700);
      }
    } catch (_) {
      _showProblem(saved
          ? 'Your song is saved. Rewards could not be confirmed yet.'
          : 'Your song could not be saved. Your progress is still here; please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!saved) return;
    if (!mounted) return;
    await _practiceDialog<void>(
      builder: (context) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text('🎉 ${song['title']} done!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: StickerBadge(randomOf(successStickers), size: 104)),
            const SizedBox(height: 8),
            if (berries > 0)
              Text('🪙 +$berries coins',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            if (fans > 0)
              Text('🕶️ +$fans fans join your crowd!',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            if (berries == 0 && fans == 0)
              const Text(
                  'Practice saved. Rewards have not been confirmed yet.'),
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

  /// Extra practice on an already-finished song: every fresh 1+ minute of
  /// sound can be banked for bonus fans.
  Future<void> _bankExtra(Map<String, dynamic> song) async {
    if (_deciding || _busy) return;
    _deciding = true;
    try {
      await _saveExtra(song);
    } finally {
      _deciding = false;
    }
  }

  Future<void> _saveExtra(Map<String, dynamic> song) async {
    final id = song['id'] as String;
    final extraMs = (_soundMsBySong[id] ?? 0) - (_bankedMs[id] ?? 0);
    final extraSeconds = extraMs ~/ 1000;
    if (extraSeconds < _minSongSeconds) return;
    if (_busy) return;
    if (_live) await _toggleLive();
    if (_live) return;
    try {
      await _retryUploads();
    } catch (_) {
      _showProblem(
          'Your recording is waiting to upload. Try again before leaving.');
      return;
    }
    var fans = 0;
    try {
      await JamJotBackend.client
          .from('session_segments')
          .upsert({
            'id': _segmentIds.putIfAbsent(id, () => const Uuid().v4()),
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
      _segmentIds.remove(id);
      _pendingClips.remove(id);
      _bankedMs[id] = _soundMsBySong[id] ?? 0;
      _bankedWallMs[id] = _wallMsBySong[id] ?? 0;
      await JamJotBackend.client
          .from('sessions')
          .update({'total_seconds': _activeSeconds}).eq('id', _sessionId!);
      final data = Map<String, dynamic>.from(await JamJotBackend.client.rpc(
          'settle_practice_session',
          params: {'p_session_id': _sessionId}));
      fans = (data['fans'] as num?)?.toInt() ?? 0;
      _earnedFans += fans;
    } catch (_) {
      _showProblem(
          'Extra practice could not be confirmed. Your progress is still here; try again before leaving.');
      return;
    }
    if (!mounted) return;
    await _practiceDialog<void>(
      builder: (context) => AlertDialog(
        scrollable: true,
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
    if (_live || _busy || !mounted) return;
    setState(() => _phase = _Phase.saving);
    _sampler?.cancel();
    if (_sessionId == null) {
      setState(() => _phase = _Phase.practicing);
      return;
    }

    try {
      await _retryUploads();
      // Persist new progress, including extra takes on completed songs.
      for (final song in _songs) {
        final id = song['id'] as String;
        final freshSeconds =
            ((_soundMsBySong[id] ?? 0) - (_bankedMs[id] ?? 0)) ~/ 1000;
        final clips = _takeClips(id);
        if (freshSeconds < 5 && clips.isEmpty) continue;
        await JamJotBackend.client.from('session_segments').upsert({
          'id': _segmentIds.putIfAbsent(id, () => const Uuid().v4()),
          'session_id': _sessionId,
          'assignment_id': id,
          'kind': 'playing',
          'seconds': freshSeconds,
          'completed': false,
          ..._clipFields(clips),
          'wall_seconds':
              ((_wallMsBySong[id] ?? 0) - (_bankedWallMs[id] ?? 0)) ~/ 1000,
        });
        _segmentIds.remove(id);
        _pendingClips.remove(id);
        _bankedMs[id] = _soundMsBySong[id] ?? 0;
        _bankedWallMs[id] = _wallMsBySong[id] ?? 0;
      }
      // Free play (recording with no song open) is kept too.
      final freeClips = _takeClips('_freeplay');
      if (freeClips.isNotEmpty) {
        await JamJotBackend.client.from('session_segments').upsert({
          'id': _segmentIds.putIfAbsent('_freeplay', () => const Uuid().v4()),
          'session_id': _sessionId,
          'kind': 'free_play',
          'seconds': 0,
          'completed': false,
          ..._clipFields(freeClips),
        });
        _segmentIds.remove('_freeplay');
        _pendingClips.remove('_freeplay');
      }

      await JamJotBackend.client.from('sessions').update({
        'ended_at': DateTime.now().toUtc().toIso8601String(),
        'total_seconds': _activeSeconds,
      }).eq('id', _sessionId!);
      final data = Map<String, dynamic>.from(await JamJotBackend.client.rpc(
          'settle_practice_session',
          params: {'p_session_id': _sessionId}));
      setState(() {
        _minutes = (data['minutes'] as num?)?.toInt() ?? _activeSeconds ~/ 60;
        _berries = ((data['berries'] as num?)?.toInt() ?? 0) + _earnedBerries;
        _fans = _earnedFans;
        _songsDone = _done.length;
        _goalMet = data['goal_met'] == true;
        _phase = _Phase.celebrate;
        _sessionSaved = true;
      });
      setUnloadGuard(false);
      playSound('fanfare');
    } catch (_) {
      if (mounted) {
        setState(() => _phase = _Phase.practicing);
        _showProblem(
            'Your practice could not be fully saved. Keep this page open and tap Finish & save again.');
      }
    }
    final sid = ref.read(activeStudentProvider)?['id'] as String?;
    if (sid != null) {
      ref.invalidate(weeklyProgressProvider(sid));
      ref.invalidate(practiceHistoryProvider(sid));
      ref.invalidate(sheetLessonsProvider(sid));
      ref.invalidate(berryBalanceProvider(sid));
      ref.invalidate(fanTotalProvider(sid));
      ref.invalidate(weeklyFansProvider(sid));
    }
  }

  Future<void> _discardPendingTake(String id) async {
    final clips = _pendingClips[id];
    if (clips == null || clips.isEmpty) return;
    final clip = clips.last;
    // Discard only the latest take. Earlier progress and recordings stay intact.
    final seconds = (clip['sound_seconds'] as num).toInt();
    final wall = (clip['wall_seconds'] as num).toInt();
    final local = clip['local_path'] as String?;
    if (local != null) await releaseRecording(local);
    if (local == null) {
      try {
        final result = await JamJotBackend.client.functions.invoke(
            'discard-recording',
            body: {'session_id': _sessionId, 'path': clip['path']});
        if ((result.data as Map?)?['ok'] != true) {
          throw StateError('Discard failed');
        }
      } catch (_) {
        _showProblem(
            'This take could not be discarded yet. Your recording is still kept. Try again.');
        return;
      }
    }
    clips.removeLast();
    _soundMsTotal = (_soundMsTotal - seconds * 1000).clamp(0, 1 << 40);
    _soundMsBySong[id] =
        ((_soundMsBySong[id] ?? 0) - seconds * 1000).clamp(0, 1 << 40);
    _wallMsBySong[id] =
        ((_wallMsBySong[id] ?? 0) - wall * 1000).clamp(0, 1 << 40);
  }

  Future<bool> _confirmLeavePractice() async {
    if (_busy || _deciding || _phase == _Phase.saving) return false;
    if (_sessionSaved || (_sessionId == null && !_live)) return true;
    if (_live) await _toggleLive();
    if (_live || !mounted) return false;
    final choice = await _practiceDialog<bool>(
        builder: (context) => AlertDialog(
              scrollable: true,
              title: const Text('Save before leaving?'),
              content: const Text(
                  'Keep your practice minutes and recordings together before you go.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Continue practicing')),
                FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Save & leave')),
              ],
            ));
    if (choice != true || !mounted) return false;
    await _finish();
    return _sessionSaved;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        _live &&
        !_busy) {
      unawaited(_toggleLive());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (identical(_exitGuard.beforeLeave, _exitHandler)) {
      _exitGuard.beforeLeave = null;
    }
    setUnloadGuard(false);
    _sampler?.cancel();
    _recorder.dispose();
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
          body:
              'Could not start the session. Give it another try!${_lastError == null ? '' : '\n\nDetails: $_lastError'}',
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

    return PopScope(
        canPop: _sessionSaved || (_sessionId == null && !_live),
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final router = GoRouter.of(context);
          if (await _confirmLeavePractice() && mounted && router.canPop()) {
            router.pop();
          }
        },
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(children: [
                if (_busy)
                  const LinearProgressIndicator(
                      semanticsLabel: 'Preparing or saving your recording'),
                if (_notice != null)
                  MaterialBanner(
                    content: Text(_notice!),
                    actions: [
                      TextButton(
                          onPressed: () => setState(() => _notice = null),
                          child: const Text('OK'))
                    ],
                  ),
                Expanded(child: body),
              ]),
            ),
          ),
        ));
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
    final baseSeconds = progress?['today_seconds'] ?? baseToday * 60;
    final persisted = progress?['session/$_sessionId'] ?? 0;
    final todayMinutes = (baseSeconds + _activeSeconds - persisted) ~/ 60;
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
      onPressed: _busy ? null : _toggleLive,
      style: FilledButton.styleFrom(
        backgroundColor: _live ? JamJotColors.recording : JamJotColors.ink,
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
              color: _soundNow ? JamJotColors.recording : JamJotColors.outline,
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
    final sched =
        ref.watch(lessonScheduleProvider(student['id'] as String)).valueOrNull;
    Widget card(String emoji, String label, Map<String, dynamic>? ev) {
      final teacher = (ev?['teachers'] as Map?)?['display_name'] as String?;
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
                  style:
                      text.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                ev == null
                    ? 'Not scheduled yet'
                    : '$when${teacher != null ? '\nwith $teacher' : ''}',
                style: text.labelSmall?.copyWith(color: JamJotColors.inkSoft),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: [
      Row(children: [
        card('🎒', 'Last lesson', sched?['last']),
        const SizedBox(width: 8),
        card('📅', 'Next lesson', sched?['next']),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => context.go(
                  '/lesson-sheet?student=${student['id']}&name=${Uri.encodeComponent(student['display_name'] as String? ?? 'Student')}'),
              icon: const Icon(Icons.print, size: 16),
              label: const Text("Print this week's lesson sheet"),
            ),
          ),
        ),
        CoinPouch(studentId: student['id'] as String),
      ]),
    ]);
  }

  Widget _buildSongList(TextTheme text) {
    final student = ref.watch(activeStudentProvider);
    final list = ListView(
      children: [
        _lessonScheduleCards(text),
        const SizedBox(height: 10),
        _goalsHeader(text),
        const SizedBox(height: 10),
        // Which stage today's practice plays at (the venue itself is the
        // page background).
        Builder(builder: (context) {
          final s2 = ref.watch(activeStudentProvider);
          return s2 == null
              ? const SizedBox.shrink()
              : FanIndicator(studentId: s2['id'] as String);
        }),
        const SizedBox(height: 10),
        _liveBanner(text),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const DancingNote(size: 56),
            const SizedBox(width: 12),
            Text(_fmt(_activeSeconds),
                style:
                    text.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('of real\nsound', style: text.labelSmall),
          ],
        ),
        const SizedBox(height: 10),
        _songs.isEmpty
            ? Center(
                child: Text(
                  'No songs assigned yet!\nAsk your grown-up or teacher to add this week\'s songs.',
                  textAlign: TextAlign.center,
                  style: text.titleSmall?.copyWith(color: JamJotColors.inkSoft),
                ),
              )
            : Builder(builder: (context) {
                final nextUp =
                    _songs.where((s) => !_done.contains(s['id'])).toList();
                final practiced =
                    _songs.where((s) => _done.contains(s['id'])).toList();
                Widget header(String label) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Text(label,
                          style: text.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    );
                return ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    if (nextUp.isNotEmpty) header('🎵 Next up'),
                    for (final song in nextUp) ...[
                      _SongTile(
                        title: song['title'] as String,
                        note: [
                          if (song['source'] != null) '🎻 ${song['source']}',
                          if ((song['song_note'] as String? ?? '').isNotEmpty)
                            song['song_note'] as String,
                        ].join(' • '),
                        minutes: (song['suggested_minutes'] as num?)?.toInt(),
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
                          minutes: (song['suggested_minutes'] as num?)?.toInt(),
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
        const SizedBox(height: 8),
        // Recording lives inside each song — tap one to start.
        if (_sessionId != null && !_sessionSaved)
          FilledButton(
            onPressed: _busy ? null : _finish,
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
    return student == null
        ? list
        : VenueBackdrop(studentId: student['id'] as String, child: list);
  }

  /// This song's practice-minutes suggestion: the teacher's number if set,
  /// otherwise the daily minutes goal split across today's songs.
  int _suggestedMinutes(Map<String, dynamic> song) {
    final set = (song['suggested_minutes'] as num?)?.toInt();
    if (set != null && set > 0) return set;
    final goal = (_lesson?['goal_minutes'] as num?)?.toInt() ?? 15;
    final songs = _songs.isEmpty ? 1 : _songs.length;
    final share = (goal / songs).ceil();
    return share < 1 ? 1 : share;
  }

  Widget _buildSongPage(TextTheme text) {
    final song = _openSong!;
    final id = song['id'] as String;
    final target = _suggestedMinutes(song);
    final note = song['song_note'] as String? ?? '';
    final lessonNote = _lesson?['lesson_note'] as String? ?? '';
    final mq = MediaQuery.of(context).size;
    final landscape = mq.width > mq.height && mq.width >= 600;

    return FutureBuilder<String?>(
      future: _scoreUrlFor(song),
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final url = snap.data;
        final hasScore = !_dialogOpen && (loading || url != null);
        final hasNotes = note.isNotEmpty || lessonNote.isNotEmpty;

        final header =
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            IconButton(
                tooltip: 'Return to songs',
                onPressed: _busy ? null : _leaveSong,
                icon: const Icon(Icons.arrow_back)),
            Expanded(
                child: Text(song['title'] as String,
                    style: text.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700))),
          ]),
          Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 12),
              child: Wrap(spacing: 16, runSpacing: 4, children: [
                Text('${_fmt(_songSeconds(id))} sound / $target min goal',
                    style:
                        text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                    '${_fmt((_wallMsBySong[id] ?? 0) ~/ 1000)} recorded in all',
                    style:
                        text.labelSmall?.copyWith(color: JamJotColors.inkSoft)),
                if (_live && _clipStartedAt != null)
                  Text('This take: ${_fmt(_clipClock.elapsed.inSeconds)}',
                      style: text.labelSmall),
              ])),
        ]);

        final notesPanel = Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: JamJotColors.marigoldTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: JamJotColors.ink, width: 2),
          ),
          child: SingleChildScrollView(
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
        );

        Widget scoreBox() {
          Widget body;
          if (loading) {
            body = const Center(child: CircularProgressIndicator());
          } else {
            final lower = url!.split('?').first.toLowerCase();
            final isImage = lower.endsWith('.png') ||
                lower.endsWith('.jpg') ||
                lower.endsWith('.jpeg');
            body = isImage
                // The whole page always fits the box; pinch to zoom in.
                ? InteractiveViewer(
                    maxScale: 5,
                    child: SizedBox.expand(
                      child: Image.network(url, fit: BoxFit.contain),
                    ),
                  )
                : buildScoreFrame(url);
          }
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: JamJotColors.outline, width: 2),
            ),
            child: body,
          );
        }

        final controls = <Widget>[
          if (_done.contains(id)) ...[
            // Already finished — fresh 1-minute chunks earn bonus fans.
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
                'Finished ✅ — ${_fmt(extraSec)} / 01:00 of extra practice toward bonus fans',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
              );
            }),
          ] else if (_live) ...[
            FilledButton(
              onPressed: _busy ? null : () => _stopAndMaybeFinishSong(song),
              style: FilledButton.styleFrom(
                  backgroundColor: JamJotColors.recording),
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
                onPressed: _busy ? null : () => _stopAndMaybeFinishSong(song),
                child: const Text('Done with this song'),
              ),
            ],
          ],
        ];

        // Landscape with music: sidebar (notes, stats, controls) on the
        // left, the score big on the right.
        if (landscape && hasScore) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              _liveBanner(text),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      // The toggle trades room between the sidebar and
                      // the music.
                      width: _scoreSmall ? mq.width * 0.45 : 290,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  minimumSize: const Size(0, 32),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10)),
                              onPressed: () =>
                                  setState(() => _scoreSmall = !_scoreSmall),
                              icon: Icon(
                                  _scoreSmall
                                      ? Icons.chevron_left
                                      : Icons.chevron_right,
                                  size: 18),
                              label: Text(_scoreSmall
                                  ? 'Bigger music'
                                  : 'Bigger notes'),
                            ),
                          ),
                          if (hasNotes)
                            Expanded(child: notesPanel)
                          else
                            const Spacer(),
                          const SizedBox(height: 10),
                          ...controls,
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: scoreBox()),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
          );
        }

        // Portrait (or no music attached).
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            _liveBanner(text),
            Expanded(
              child: !hasScore
                  ? (hasNotes ? notesPanel : const SizedBox.expand())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                minimumSize: const Size(0, 32),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10)),
                            onPressed: () =>
                                setState(() => _scoreSmall = !_scoreSmall),
                            icon: Icon(
                                _scoreSmall
                                    ? Icons.unfold_more
                                    : Icons.unfold_less,
                                size: 16),
                            label: Text(
                                _scoreSmall ? 'Bigger music' : 'Smaller music'),
                          ),
                        ),
                        Expanded(flex: _scoreSmall ? 2 : 5, child: scoreBox()),
                        if (hasNotes) ...[
                          const SizedBox(height: 10),
                          if (_scoreSmall)
                            Expanded(flex: 3, child: notesPanel)
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 120),
                              child: notesPanel,
                            ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            ...controls,
          ],
        );
      },
    );
  }

  Widget _buildCelebrate(TextTheme text) {
    final goal = (_lesson?['goal_minutes'] as num?)?.toInt() ?? 15;
    return Column(
      children: [
        const Spacer(),
        StickerBadge(randomOf(successStickers), size: 130),
        const SizedBox(height: 8),
        Text(
            'You made $_minutes minute${_minutes == 1 ? '' : 's'} of real music!',
            textAlign: TextAlign.center,
            style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        if (_songsDone > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
                '$_songsDone song${_songsDone == 1 ? '' : 's'} finished',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
        if (_fans > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
            child: Text('🪙 +$_berries coins in your pouch!',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (_goalMet)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Session goal reached — amazing!',
                  style: text.titleSmall?.copyWith(color: JamJotColors.leaf)),
            ),
        ] else ...[
          Text(
            'Your daily goal is $goal sound-minutes. Every bit of practice helps — keep going when you are ready!',
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
                style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
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
