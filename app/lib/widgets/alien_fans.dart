import 'dart:math' as math;

import 'package:flutter/material.dart';

/// NoteStar fans (2026-11-16): Erika's paper aliens, recoloured to the
/// palette, standing as a little crowd. [cheering] makes them hop up and
/// down (each on its own beat); with "reduce motion" on they stand still.
class AlienCrowd extends StatefulWidget {
  const AlienCrowd({super.key, this.width = 320, this.cheering = true});
  final double width;
  final bool cheering;
  @override
  State<AlienCrowd> createState() => _AlienCrowdState();
}

// alien, x centre, ground y, height (on a 900 x 600 stage), beat frames, phase, sway
const _crowd = [
  (1, 215.0, 450.0, 290.0, 16, 0, 1),
  (3, 455.0, 395.0, 300.0, 24, 8, -1),
  (4, 715.0, 450.0, 300.0, 12, 3, 1),
  (0, 320.0, 585.0, 300.0, 12, 6, -1),
  (2, 565.0, 585.0, 330.0, 16, 10, 1),
];
// Width / height of each alien picture.
const _aspect = [0.883, 1.002, 0.885, 1.012, 0.898];

class _AlienCrowdState extends State<AlienCrowd>
    with SingleTickerProviderStateMixin {
  // 96 frames at 25 a second: every beat divides it, so the loop is seamless.
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3840));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AlienCrowd old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final move = widget.cheering && !MediaQuery.of(context).disableAnimations;
    if (move && !_c.isAnimating) {
      _c.repeat();
    } else if (!move) {
      _c.stop();
      _c.value = .1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.width / 900;
    return Semantics(
      label: 'A crowd of alien fans cheering',
      child: SizedBox(
        width: widget.width,
        height: 600 * k,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final f = _c.value * 96;
            return Stack(clipBehavior: Clip.none, children: [
              for (final (a, x, gy, h, beat, phase, sway) in _crowd)
                _alien(f, k, a, x, gy, h, beat, phase, sway),
            ]);
          },
        ),
      ),
    );
  }

  Widget _alien(double f, double k, int a, double x, double gy, double h,
      int beat, int phase, int sway) {
    final t = ((f + phase) % beat) / beat;
    final air = math.sin(math.pi * t);
    final ground = math.max(0.0, 1 - air * 4);
    final sy = 1 - .08 * ground + .04 * air;
    final sx = 1 + .06 * ground - .03 * air;
    final rot = sway * .1 * math.sin(math.pi * (f + phase) / beat);
    final hh = h * k, ww = hh * _aspect[a];
    final hop = hh * .16 * air;
    return Positioned(
      left: x * k - ww / 2,
      top: gy * k - hh - hop + 8 * k,
      width: ww,
      height: hh,
      child: Transform.rotate(
        angle: rot,
        alignment: Alignment.bottomCenter,
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(sx, sy, 1),
          child: Image.asset('assets/art/notestar/alien_$a.png',
              fit: BoxFit.contain, gaplessPlayback: true),
        ),
      ),
    );
  }
}
