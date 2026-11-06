import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ms. Straw-ccato at her grape-footed piano (founder art, 2026-11-05).
///
/// Layered cutout animation per claude/avatar-animation-rules.md: the
/// armless scene is the base, each arm rotates about its own drawn
/// attachment point (so it can never detach), and the music is the
/// approved traveling-wave render shipped as a transparent animated WebP.
///
/// [playing] eases the whole scene between still and playing over ~0.8 s —
/// arms and music wake together, exactly like the practice screen's
/// sound gate.
class StrawccatoPiano extends StatefulWidget {
  const StrawccatoPiano({super.key, required this.playing, this.height = 96});

  final bool playing;
  final double height;

  @override
  State<StrawccatoPiano> createState() => _StrawccatoPianoState();
}

class _StrawccatoPianoState extends State<StrawccatoPiano>
    with TickerProviderStateMixin {
  // Scene canvas the layers were exported on, and the measured pivots
  // (fractions of that canvas — the arms' drawn attachment points).
  static const _w = 1127.0, _h = 1386.0;
  static const _pivotUpper = Offset(0.31863 * _w, 0.57323 * _h);
  static const _pivotLower = Offset(0.34161 * _w, 0.59545 * _h);
  static const _musicRect =
      Rect.fromLTWH(0.55590 * _w, 0.00556 * _h, 0.43478 * _w, 0.34798 * _h);

  late final AnimationController _beat = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat();
  late final AnimationController _wake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: widget.playing ? 1 : 0);

  @override
  void didUpdateWidget(covariant StrawccatoPiano old) {
    super.didUpdateWidget(old);
    if (widget.playing && !old.playing) _wake.forward();
    if (!widget.playing && old.playing) _wake.reverse();
  }

  @override
  void dispose() {
    _beat.dispose();
    _wake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AspectRatio(
        aspectRatio: _w / _h,
        child: AnimatedBuilder(
          animation: Listenable.merge([_beat, _wake]),
          builder: (context, _) {
            final e = Curves.easeInOut.transform(_wake.value);
            final t = _beat.value;
            final upper =
                e * 6.0 * math.sin(2 * math.pi * (2 * t)) * math.pi / 180;
            final lower =
                e * 6.0 * math.sin(2 * math.pi * (2 * t + 0.5)) * math.pi / 180;
            return LayoutBuilder(builder: (context, c) {
              final s = c.maxWidth / _w;
              Widget arm(String name, Offset pivot, double ang) =>
                  Positioned.fill(
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translate(pivot.dx * s, pivot.dy * s)
                        ..rotateZ(ang)
                        ..translate(-pivot.dx * s, -pivot.dy * s),
                      child: Image.asset('assets/art/piano/$name',
                          fit: BoxFit.fill),
                    ),
                  );
              return Stack(children: [
                Positioned.fill(
                  child: Image.asset('assets/art/piano/straw_piano_base.png',
                      fit: BoxFit.fill),
                ),
                // The music pours out of the lid only while there's sound.
                if (e > 0.01)
                  Positioned(
                    left: _musicRect.left * s,
                    top: _musicRect.top * s,
                    width: _musicRect.width * s,
                    height: _musicRect.height * s,
                    child: Opacity(
                      opacity: e,
                      child: Image.asset(
                          'assets/art/piano/straw_piano_music.webp',
                          fit: BoxFit.fill,
                          gaplessPlayback: true),
                    ),
                  ),
                arm('straw_piano_arm_lower.png', _pivotLower, lower),
                arm('straw_piano_arm_upper.png', _pivotUpper, upper),
              ]);
            });
          },
        ),
      ),
    );
  }
}
