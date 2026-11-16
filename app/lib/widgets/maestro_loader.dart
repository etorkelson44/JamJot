
import 'package:flutter/material.dart';

import 'notestar_art.dart';

/// JamJot's loading indicator: Maestro Marmalade conducting a little song
/// while the app thinks. Replaces the generic spinner on full-screen waits.
///
/// He stands still and conducts with his pencil baton while three notes
/// float up past it, each on its own beat.
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
    // NoteStar (2026-11-15): the star-note bobs while the app thinks. The
    // piano only appears on piano pages.
    return Column(mainAxisSize: MainAxisSize.min, children: [
      StarBounce(size: widget.size),
      if (widget.label != null) ...[
        const SizedBox(height: 8),
        Text(widget.label!, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ]);
  }
}
