import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import '../state/wardrobe.dart';
import 'dressed_avatar.dart';

/// Instrument props the avatar can play (placeholder art — each swaps to a
/// drawn piece with the art pass, same keys).
const _instrumentEmoji = <String, String>{
  'piano': '🎹',
  'keyboard': '🎹',
  'violin': '🎻',
  'viola': '🎻',
  'cello': '🎻',
  'bass': '🎻',
  'guitar': '🎸',
  'ukulele': '🎸',
  'drums': '🥁',
  'percussion': '🥁',
  'voice': '🎤',
  'singing': '🎤',
  'flute': '🪈',
  'recorder': '🪈',
  'clarinet': '🪈',
  'saxophone': '🎷',
  'trumpet': '🎺',
  'trombone': '🎺',
  'harp': '🪕',
  'banjo': '🪕',
};

String _propFor(String? instrument) {
  if (instrument == null) return '🎵';
  final key = instrument.trim().toLowerCase();
  for (final entry in _instrumentEmoji.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return '🎵';
}

/// The active student's dressed avatar performing on their own instrument:
/// a gentle 3/4-time sway, the instrument at their hands, and music notes
/// floating up while they play.
class PerformingAvatar extends ConsumerStatefulWidget {
  const PerformingAvatar({super.key, this.size = 84, this.instrument});

  final double size;

  /// The instrument being practiced; falls back to the student's first
  /// listed instrument, then to a plain music note.
  final String? instrument;

  @override
  ConsumerState<PerformingAvatar> createState() => _PerformingAvatarState();
}

class _PerformingAvatarState extends ConsumerState<PerformingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeStudentProvider);
    final wornKey = (active?['avatar_key'] as String?) ?? 'sonatina';
    final sid = active?['id'] as String?;
    final outfit = sid == null
        ? const <String>[]
        : ref.watch(wardrobeProvider(sid)).outfitFor(wornKey);
    final instruments = (active?['instruments'] as List?)?.cast<String>();
    final prop = _propFor(widget.instrument ??
        (instruments != null && instruments.isNotEmpty
            ? instruments.first
            : null));
    final s = widget.size;

    return SizedBox(
      width: s * 1.5,
      height: s * 1.2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final sway = math.sin(t * 2 * math.pi) * 0.06;
          final bob = math.sin(t * 4 * math.pi).abs() * 3;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Floating notes while the music plays.
              for (var i = 0; i < 2; i++)
                Positioned(
                  bottom: s * 0.5 + ((t + i * 0.5) % 1) * s * 0.65,
                  right: s * 0.08 + i * s * 0.14,
                  child: Opacity(
                    opacity: (1 - ((t + i * 0.5) % 1)).clamp(0.0, 0.9),
                    child: Text(i.isEven ? '♪' : '♫',
                        style: TextStyle(
                            fontSize: s * 0.26,
                            color: const Color(0xFF6C4A91))),
                  ),
                ),
              // The musician, swaying in time.
              Positioned(
                bottom: bob,
                child: Transform.rotate(
                  angle: sway,
                  alignment: Alignment.bottomCenter,
                  child: DressedAvatar(
                      avatarKey: wornKey, outfit: outfit, size: s),
                ),
              ),
              // Their instrument, right at their hands.
              Positioned(
                bottom: s * 0.08 - bob * 0.4,
                right: s * 0.02,
                child: Transform.rotate(
                  angle: -sway * 0.6,
                  child: Text(prop, style: TextStyle(fontSize: s * 0.42)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
