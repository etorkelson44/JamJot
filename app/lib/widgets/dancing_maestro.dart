
import 'package:flutter/material.dart';
import 'notestar_art.dart';


/// Maestro Marmalade, doing a little dance once when the screen loads:
/// a happy hop with a side-to-side wiggle, then settling into place.
class DancingMaestro extends StatefulWidget {
  const DancingMaestro({super.key, this.size = 230, this.asset});

  final double size;

  /// Which mascot image to dance. Maestro is the shared default on sign-in,
  /// child Home, Practice, and invitations.
  final String? asset;

  @override
  State<DancingMaestro> createState() => _DancingMaestroState();
}

class _DancingMaestroState extends State<DancingMaestro>
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
  Widget build(BuildContext context) =>
      // NoteStar (2026-11-15): the star-note with paper accents replaces
      // Maestro; the piano only appears on piano pages.
      StarCluster(width: widget.size, animate: true);
}
