import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Maestro Marmalade conducting: his body stands still while his pencil-baton
/// arm sweeps a 3/4-time beat. The art is split into two layers —
/// maestro_body.png (toast, tux, waving hand) drawn over maestro_arm.png
/// (pencil + glove + sleeve), which rotates around his shoulder.
class ConductingMaestro extends StatefulWidget {
  const ConductingMaestro({super.key, this.height = 130});

  final double height;

  /// Where the shoulder pivot sits inside the 640x567 art,
  /// expressed as an Alignment (x: 124/640, y: 292/567).
  static const Alignment _pivot = Alignment(-0.6125, 0.03);

  @override
  State<ConductingMaestro> createState() => _ConductingMaestroState();
}

class _ConductingMaestroState extends State<ConductingMaestro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Source art is 640x567.
    final h = widget.height;
    final w = h * (640 / 567);
    return SizedBox(
      width: w,
      height: h,
      child: AnimatedBuilder(
        animation: _beat,
        builder: (context, _) {
          final t = _beat.value;
          // A conductor's lilt: one big sweep per bar with a small
          // second accent, swinging roughly -18 .. +16 degrees.
          final angle = -0.02 +
              0.26 * math.sin(t * 2 * math.pi) +
              0.06 * math.sin(t * 4 * math.pi + 1.2);
          return Stack(
            fit: StackFit.expand,
            children: [
              Transform.rotate(
                angle: angle,
                alignment: ConductingMaestro._pivot,
                child: Image.asset('assets/mascot/maestro_arm.png',
                    fit: BoxFit.contain),
              ),
              Image.asset(
                'assets/mascot/maestro_body.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                    'assets/mascot/maestro_tux.png',
                    fit: BoxFit.contain),
              ),
            ],
          );
        },
      ),
    );
  }
}
