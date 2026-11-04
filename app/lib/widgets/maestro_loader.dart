import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/jamjot_theme.dart';

/// JamJot's loading indicator: Maestro Marmalade conducting a little song
/// while the app thinks. Replaces the generic spinner on full-screen waits.
///
/// He sways in 3/4 time around his shoes, and three notes float up past his
/// baton, each on its own beat.
class MaestroLoader extends StatefulWidget {
  const MaestroLoader({super.key, this.size = 120, this.label});

  final double size;

  /// Optional line under the maestro, e.g. "Warming up the orchestra…".
  final String? label;

  @override
  State<MaestroLoader> createState() => _MaestroLoaderState();
}

class _MaestroLoaderState extends State<MaestroLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteColor = Theme.of(context).colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size * 1.5,
          height: widget.size * 1.3,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              // A gentle 3/4-time sway, pivoting at his shoes.
              final sway = math.sin(t * math.pi * 2) * 0.09;
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Floating notes, staggered on the beat.
                  for (var i = 0; i < 3; i++) _note(t, i, noteColor),
                  Transform.rotate(
                    angle: sway,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                ],
              );
            },
            child: Image.asset(
              'assets/mascot/maestro_tux.png',
              height: widget.size,
              errorBuilder: (_, __, ___) => SizedBox(
                width: widget.size * 0.4,
                height: widget.size * 0.4,
                child: const CircularProgressIndicator(),
              ),
            ),
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 10),
          Text(
            widget.label!,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: JamJotColors.inkSoft),
          ),
        ],
      ],
    );
  }

  /// One floating note: rises and fades, offset to its own beat.
  Widget _note(double t, int i, Color color) {
    final phase = (t + i / 3) % 1.0;
    final glyphs = ['♪', '♫', '♩'];
    final x = (i - 1) * 0.5 + math.sin(phase * math.pi * 2 + i) * 0.12;
    return Align(
      alignment: Alignment(x, 1 - phase * 2), // bottom → top
      child: Opacity(
        opacity: (1 - phase) * 0.9,
        child: Text(
          glyphs[i],
          style: TextStyle(
            fontSize: 16 + 6 * (1 - phase),
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
