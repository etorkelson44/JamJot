import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'jar_logo.dart';

/// Erika's note mascot, doing a little dance once when the screen loads:
/// a happy hop with a side-to-side wiggle, then settling into place.
class DancingNote extends StatefulWidget {
  const DancingNote({super.key, this.size = 230});

  final double size;

  @override
  State<DancingNote> createState() => _DancingNoteState();
}

class _DancingNoteState extends State<DancingNote>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    // A short beat after the page appears, then dance once.
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Wiggle: a few side-to-side tilts that fade out as the dance ends.
        final wiggle = math.sin(t * math.pi * 6) * 0.10 * (1 - t);
        // Hop: two little jumps that also settle down.
        final hop = (math.sin(t * math.pi * 4).abs()) * 14 * (1 - t);
        return Transform.translate(
          offset: Offset(0, -hop),
          child: Transform.rotate(angle: wiggle, child: child),
        );
      },
      child: Image.asset(
        'assets/mascot/note.png',
        height: widget.size,
        errorBuilder: (_, __, ___) => JarLogo(size: widget.size),
      ),
    );
  }
}
