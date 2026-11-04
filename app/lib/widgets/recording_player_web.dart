import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class RecordingPlayer extends StatefulWidget {
  const RecordingPlayer({super.key, required this.url});
  final String url;
  @override
  State<RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends State<RecordingPlayer> {
  web.HTMLAudioElement? _audio;
  bool _failed = false;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        if (_failed)
          const Text(
              'This recording could not be played. Close and reopen it to refresh its link.'),
        SizedBox(
            height: 64,
            width: 320,
            child: HtmlElementView.fromTagName(
              tagName: 'audio',
              onElementCreated: (element) {
                final audio = element as web.HTMLAudioElement;
                _audio = audio;
                audio
                  ..controls = true
                  ..preload = 'metadata'
                  ..src = widget.url;
                audio.style.width = '100%';
                audio.addEventListener(
                    'error',
                    ((web.Event event) {
                      if (mounted) setState(() => _failed = true);
                    }).toJS);
              },
            )),
      ]);
  @override
  void dispose() {
    _audio?.pause();
    _audio?.removeAttribute('src');
    _audio?.load();
    super.dispose();
  }
}
