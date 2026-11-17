import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/jamjot_theme.dart';
import 'alien_fans.dart';
import 'notestar_art.dart';
import 'star_currency.dart';

/// NoteStar (2026-11-17): the "Mission complete!" celebration shown when a
/// kid meets their daily practice goal. A deep-space paper panel: the rocket
/// bobs, paper stars twinkle, the alien fans cheer below, and the stars and
/// fans earned are shown as rewards. Still when "reduce motion" is on.
class MissionComplete extends StatefulWidget {
  const MissionComplete({
    super.key,
    required this.minutes,
    required this.goalMinutes,
    this.stars = 0,
    this.fans = 0,
  });
  final int minutes, goalMinutes, stars, fans;
  @override
  State<MissionComplete> createState() => _MissionCompleteState();
}

// accent, x (0..1), y (0..1), size, twinkle phase
const _sky = [
  ('star_big_lime', .08, .10, 30.0, 0.0),
  ('star_small_violet', .24, .30, 18.0, .4),
  ('dot_pink', .14, .52, 12.0, .7),
  ('star_big_blue', .86, .12, 26.0, .2),
  ('moon_blue', .78, .40, 34.0, .9),
  ('dot_lime', .92, .58, 10.0, .5),
  ('star_big_pink', .62, .06, 18.0, .6),
  ('mini_star_white', .40, .14, 14.0, .3),
  ('mini_star_white', .70, .55, 12.0, .8),
];

class _MissionCompleteState extends State<MissionComplete>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label:
          'Mission complete! You met your daily goal of ${widget.goalMinutes} minutes.',
      child: Container(
        decoration: BoxDecoration(
          color: JamJotColors.ink,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: JamJotColors.ink, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: 210,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = _c.value * 2 * math.pi;
                  return Stack(clipBehavior: Clip.none, children: [
                    for (final (name, x, y, s, ph) in _sky)
                      Positioned(
                        left: x * w - s / 2,
                        top: y * 210,
                        child: Transform.scale(
                          scale: .75 + .25 * (1 + math.sin(t + ph * 6.3)) / 2,
                          child: PaperAccent(name, size: s),
                        ),
                      ),
                    Positioned(
                      left: w / 2 - 60,
                      top: 18 + 10 * math.sin(t),
                      child: Transform.rotate(
                        angle: .06 * math.sin(t * .5),
                        child: Image.asset(
                            'assets/art/notestar/rocket_violet.png',
                            height: 180,
                            excludeFromSemantics: true),
                      ),
                    ),
                  ]);
                },
              ),
            ),
            Text('Mission complete!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: JamJotType.display,
                    fontSize: 36,
                    height: 1.1,
                    color: JamJotColors.marigold)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'You hit your daily goal: ${widget.minutes} of ${widget.goalMinutes} minutes.',
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                if (widget.stars > 0)
                  _Reward(
                      icon: const StarIcon(size: 26),
                      label: '+${widget.stars} stars'),
                if (widget.fans > 0)
                  _Reward(
                      icon: Image.asset('assets/art/notestar/fan_alien.png',
                          width: 26, height: 26, excludeFromSemantics: true),
                      label: '+${widget.fans} fans'),
              ],
            ),
            const SizedBox(height: 8),
            const AlienCrowd(width: 280),
            const SizedBox(height: 4),
          ]);
        }),
      ),
    );
  }
}

class _Reward extends StatelessWidget {
  const _Reward({required this.icon, required this.label});
  final Widget icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 16, 6),
        decoration: BoxDecoration(
          color: JamJotColors.marigold,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          icon,
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontFamily: JamJotType.title,
                  fontSize: 20,
                  color: JamJotColors.ink)),
        ]),
      );
}
