import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class RecordingPlayer extends StatefulWidget {
  const RecordingPlayer({super.key, required this.url});
  final String url;
  @override
  State<RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends State<RecordingPlayer> {
  final _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _subscriptions.add(_player.onDurationChanged.listen((value) {
      if (mounted) setState(() => _duration = value);
    }, onError: _failed));
    _subscriptions.add(_player.onPositionChanged.listen((value) {
      if (mounted) setState(() => _position = value);
    }, onError: _failed));
    _subscriptions.add(_player.onPlayerStateChanged.listen((value) {
      if (mounted) setState(() => _playing = value == PlayerState.playing);
    }, onError: _failed));
  }

  void _failed(Object error) {
    if (mounted) {
      setState(() => _error =
          'This recording could not be played. Close and reopen it to refresh its link.');
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_playing) {
        await _player.pause();
      } else if (_player.state == PlayerState.paused) {
        await _player.resume();
      } else {
        await _player.play(UrlSource(widget.url));
      }
    } catch (error) {
      _failed(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) Text(_error!),
        FilledButton.icon(
            onPressed: _busy ? null : _toggle,
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
            label: Text(_playing ? 'Pause recording' : 'Play recording')),
        if (_duration > Duration.zero) ...[
          Text('${_time(_position)} / ${_time(_duration)}'),
          Slider(
              label: 'Recording position',
              value: _position.inMilliseconds
                  .clamp(0, _duration.inMilliseconds)
                  .toDouble(),
              max: _duration.inMilliseconds.toDouble(),
              onChanged: (value) async {
                try {
                  await _player.seek(Duration(milliseconds: value.round()));
                } catch (error) {
                  _failed(error);
                }
              }),
        ],
      ]);
  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }
}
