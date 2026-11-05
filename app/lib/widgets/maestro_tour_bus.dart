import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Maestro Marmalade at the wheel of the JamJot tour bus — the "you are
/// here" marker beside the student's current venue.
///
/// Idle it's a still; on desktop, hovering the pointer over it plays the
/// full run (engine idle + Maestro's honk + exhaust puffs curling around
/// the back), and on phones and tablets a tap does the same. The run lasts
/// 4.604 s, matching `assets/audio/bus_idle_honk.mp3` (the founder's idle
/// recording with the honk mixed in at 0.834 s). Sound is a treat, never a
/// crash: if the browser or device declines to play it (e.g. a hover
/// before the page's first tap), the animation still runs silently.
class MaestroTourBus extends StatefulWidget {
  const MaestroTourBus({super.key, this.width = 96, this.semanticsLabel});
  final double width;
  final String? semanticsLabel;

  @override
  State<MaestroTourBus> createState() => _MaestroTourBusState();
}

class _MaestroTourBusState extends State<MaestroTourBus>
    with SingleTickerProviderStateMixin {
  /// Length of one full run, matched to the mixed audio file.
  static const _runMs = 4604;

  /// When the honk lands inside the audio (for the little bounce).
  static const _honkS = 0.834;

  late final AnimationController _run = AnimationController(
      vsync: this, duration: const Duration(milliseconds: _runMs));
  AudioPlayer? _player;

  @override
  void dispose() {
    _run.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_run.isAnimating) return; // let the current run finish
    _run.forward(from: 0);
    final old = _player;
    final p = AudioPlayer();
    _player = p;
    try {
      await old?.dispose();
    } catch (_) {}
    try {
      await p.play(AssetSource('audio/bus_idle_honk.mp3'), volume: .9);
    } catch (_) {
      /* Autoplay policies may decline a hover-triggered sound. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    return Semantics(
      label: widget.semanticsLabel ??
          'The JamJot tour bus — you are here. '
              'Tap to hear Maestro honk hello.',
      button: true,
      child: MouseRegion(
        onEnter: (_) => _go(),
        child: GestureDetector(
          onTap: _go,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: w,
            height: w,
            child: AnimatedBuilder(
              animation: _run,
              builder: (context, _) {
                final s = _run.value * _runMs / 1000.0; // seconds into run
                final active = _run.isAnimating;
                // Road bounce + driver sway, in fractions of the width so
                // the motion scales with the bus.
                var busDy = active ? 0.005 * math.sin(s * 10) : 0.0;
                var drvDy = active ? 0.009 * math.sin(s * 10 + 0.9) : 0.0;
                final rot = active ? 0.024 * math.sin(s * 2.1) : 0.0;
                // A happy bounce right when the honk sounds.
                if (active && s > _honkS) {
                  final b = math.exp(-5 * (s - _honkS));
                  busDy -= 0.016 * b;
                  drvDy -= 0.022 * b;
                }
                return Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    if (active) ..._puffs(s, w),
                    _layer('assets/art/tourbus_interior.png', busDy * w),
                    Transform.rotate(
                      angle: rot,
                      child:
                          _layer('assets/art/tourbus_driver.png', drvDy * w),
                    ),
                    _layer('assets/art/tourbus_front.png', busDy * w),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _layer(String asset, double dy) => Transform.translate(
        offset: Offset(0, dy),
        child: Image.asset(asset, fit: BoxFit.contain),
      );

  /// Cartoon exhaust, curling up and around the back of the bus: six puffs
  /// staggered through the run, three per side, drawn behind the bus.
  List<Widget> _puffs(double s, double w) {
    const life = 1.9; // seconds each puff lives
    final widgets = <Widget>[];
    for (var k = 0; k < 6; k++) {
      final side = k.isEven ? -1.0 : 1.0;
      final start = k * 0.45;
      final u = (s - start) / life;
      if (u <= 0 || u >= 1) continue;
      final e = 1 - (1 - u) * (1 - u); // ease out
      final x0 = side < 0 ? 0.34 : 0.66, x1 = side < 0 ? 0.10 : 0.90;
      final y1 = 0.60 + 0.06 * (k % 3);
      final x = x0 + (x1 - x0) * e + side * 0.008 * math.sin(u * 6);
      final y = 0.92 + (y1 - 0.92) * e;
      final size = w * (0.09 + 0.21 * e);
      final opacity = (1 - math.pow(u, 1.8)).clamp(0.0, 1.0).toDouble();
      widgets.add(Positioned(
        left: x * w - size / 2,
        top: y * w - size / 2,
        width: size,
        height: size,
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: side * 0.44 * u,
            child: Image.asset('assets/art/tourbus_puff.png'),
          ),
        ),
      ));
    }
    return widgets;
  }
}
