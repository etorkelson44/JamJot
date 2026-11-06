import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Maestro Marmalade conducting with BOTH arms. His body stands still while
/// his pencil-baton arm and his open-hand arm swing in and out together.
///
/// The art is five layers on one shared canvas (so every layer is the same
/// size and the pivots below are simple fractions of it):
///  - maestro_arm.png        baton arm (behind the toast: the sleeve tucks in)
///  - maestro_arm_open.png   open-hand arm (behind the toast)
///  - maestro_body.png       toast, tux and legs — no arms
///  - maestro_arm_front.png  the baton arm again, faded in beyond the
///                           shoulder, so the glove and pencil pass IN FRONT
///                           of the toast head on the swing in while the
///                           sleeve end stays tucked behind it
///
/// Both arms are driven from one beat value (a single sine, same phase), in
/// the same frame, so they move in and out together with no lag. Each arm
/// turns about its own drawn shoulder end, so it can't come loose.
class ConductingMaestro extends StatefulWidget {
  const ConductingMaestro({super.key, this.height = 130});

  final double height;

  // The shared canvas the layers were cut from (a crop of the 2000px art).
  static const double _artW = 1710;
  static const double _artH = 1640;

  // Each arm's sleeve end (its shoulder pivot) as an Alignment on the canvas:
  // baton arm at (419, 846), open-hand arm at (1351, 848).
  static const Alignment _batonPivot = Alignment(-0.5103, 0.0317);
  static const Alignment _openPivot = Alignment(0.5801, 0.0341);

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

  static double _rad(double deg) => deg * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    final w = h * (ConductingMaestro._artW / ConductingMaestro._artH);
    return SizedBox(
      width: w,
      height: h,
      child: AnimatedBuilder(
        animation: _beat,
        builder: (context, _) {
          // One sine for both arms: s = +1 is "in", s = -1 is "out".
          // Flutter angles turn clockwise (+) / counter-clockwise (-).
          // Baton arm swings clockwise on "in": +18 deg in .. -8 deg out.
          // Open-hand arm swings counter-clockwise on "in" (its hand rises):
          // -16 deg in .. +12 deg out.
          final s = math.sin(_beat.value * 2 * math.pi);
          final batonAngle = _rad(5 + 13 * s);
          final openAngle = _rad(-2 - 14 * s);

          Widget arm(String asset, double angle, Alignment pivot) =>
              Transform.rotate(
                angle: angle,
                alignment: pivot,
                child: Image.asset(asset,
                    fit: BoxFit.contain, filterQuality: FilterQuality.medium),
              );

          return Stack(
            fit: StackFit.expand,
            children: [
              arm('assets/mascot/maestro_arm.png', batonAngle,
                  ConductingMaestro._batonPivot),
              arm('assets/mascot/maestro_arm_open.png', openAngle,
                  ConductingMaestro._openPivot),
              Image.asset(
                'assets/mascot/maestro_body.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                    'assets/mascot/maestro_tux.png',
                    fit: BoxFit.contain),
              ),
              arm('assets/mascot/maestro_arm_front.png', batonAngle,
                  ConductingMaestro._batonPivot),
            ],
          );
        },
      ),
    );
  }
}
