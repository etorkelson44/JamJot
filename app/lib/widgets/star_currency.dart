import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/jamjot_theme.dart';

/// NoteStar stars (2026-11-16): the currency. A violet paper star with a
/// lime inner layer and the count cut into the middle. When stars are
/// earned it grows from the corner to the middle of the screen, little paper
/// stars pour into it, the inner layer puffs fuller with each one (the
/// outline never grows) and the count ticks up, then it flies home.

const _base = 'assets/art/notestar/star_currency_base.png';
const _inner = 'assets/art/notestar/star_currency_inner.png';
const _full = 'assets/art/notestar/star_currency.png';
// Where the inner layer's middle sits in the 239 x 236 artwork.
const _cx = .457, _cy = .486;
const _innerAlign = Alignment(_cx * 2 - 1, _cy * 2 - 1);
const _minis = ['blue', 'pink', 'white', 'lime', 'violet'];

/// The small star used beside prices and balances.
class StarIcon extends StatelessWidget {
  const StarIcon({super.key, this.size = 20});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: Image.asset(_full,
          width: size,
          height: size,
          fit: BoxFit.contain,
          gaplessPlayback: true));
}

/// The star with its count, at rest. [puff] 0..1 is how full the inner
/// paper layer is (1 = full, the resting look).
class StarStill extends StatelessWidget {
  const StarStill(
      {super.key,
      required this.balance,
      required this.width,
      this.puff = 1,
      this.squashX = 1,
      this.squashY = 1});
  final int? balance;
  final double width;
  final double puff, squashX, squashY;
  @override
  Widget build(BuildContext context) {
    final h = width * 236 / 239;
    final label = balance == null ? '' : '$balance';
    final fs = width *
        (label.length >= 4
            ? .19
            : label.length == 3
                ? .23
                : .27);
    final style = TextStyle(
        fontFamily: JamJotType.display,
        fontSize: fs,
        height: 1,
        letterSpacing: .5);
    return Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.diagonal3Values(squashX, squashY, 1),
      child: SizedBox(
        width: width,
        height: h,
        child: Stack(children: [
          Positioned.fill(
              child:
                  Image.asset(_base, fit: BoxFit.fill, gaplessPlayback: true)),
          Positioned.fill(
              child: Transform.scale(
                  scale: .5 + .5 * puff.clamp(0, 1.08),
                  alignment: _innerAlign,
                  child: Image.asset(_inner,
                      fit: BoxFit.fill, gaplessPlayback: true))),
          if (label.isNotEmpty)
            Positioned(
              left: 0,
              top: 0,
              width: width * _cx * 2,
              height: h * _cy * 2,
              child: Center(
                child: Stack(children: [
                  Text(label,
                      style: style.copyWith(
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = math.max(2, width * .025)
                            ..strokeJoin = StrokeJoin.round
                            ..color = Colors.white)),
                  Text(label, style: style.copyWith(color: JamJotColors.ink)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// When things happen in the earning moment (milliseconds from its start).
class StarTimeline {
  StarTimeline({required this.start, required int earn})
      : earn = math.max(1, earn) {
    n = math.min(this.earn, 12);
    stagger = math.min(280.0, 2400.0 / n);
    final base = this.earn ~/ n, rem = this.earn - base * n;
    var run = start;
    for (var i = 0; i < n; i++) {
      lands.add(firstLand + i * stagger);
      run += base + (i < rem ? 1 : 0);
      tickValues.add(run);
    }
    lastLand = lands.last;
    wiggle0 = lastLand + 150;
    wiggle1 = lastLand + 650;
    flyOut0 = lastLand + 1300;
    total = flyOut0 + 600;
  }

  static const tagIn = 0.0, flyIn0 = 350.0, flyIn1 = 1000.0, firstLand = 1500.0;
  static const miniFlight = 520.0;
  final int start, earn;
  late final int n;
  late final double stagger, lastLand, wiggle0, wiggle1, flyOut0, total;
  final lands = <double>[];
  final tickValues = <int>[];

  /// When each little star lands: when each coin blip should play.
  List<int> get tickDelays => [for (final l in lands) l.round()];
  int get endCount => start + earn;
}

double _cl(double x) => x.clamp(0.0, 1.0);
double _eio(double t) =>
    t < .5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;
double _eob(double t) {
  const c1 = 1.5, c3 = c1 + 1;
  return 1 +
      c3 * math.pow(t - 1, 3).toDouble() +
      c1 * math.pow(t - 1, 2).toDouble();
}

/// The full-screen earning moment. [cornerCenter]/[cornerWidth] are where the
/// resting star sits; without them it starts and ends top-right.
class StarFlight extends StatefulWidget {
  const StarFlight({
    super.key,
    required this.startCount,
    required this.earned,
    this.cornerCenter,
    this.cornerWidth = 56,
    this.onDone,
  });
  final int startCount, earned;
  final Offset? cornerCenter;
  final double cornerWidth;
  final VoidCallback? onDone;
  @override
  State<StarFlight> createState() => _StarFlightState();
}

class _StarFlightState extends State<StarFlight>
    with SingleTickerProviderStateMixin {
  late final StarTimeline tl =
      StarTimeline(start: widget.startCount, earn: widget.earned);
  late final AnimationController _c = AnimationController(
      vsync: this, duration: Duration(milliseconds: tl.total.round()))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final corner = widget.cornerCenter ?? Offset(w - 40, 44);
      final small = widget.cornerWidth;
      final big = math.min(240.0, math.min(w * .58, h * .34));
      final mid = Offset(w / 2, h * .44);
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * tl.total;
          // Where the star is and how big.
          double k;
          if (t < StarTimeline.flyIn0) {
            k = 0;
          } else if (t < StarTimeline.flyIn1) {
            k = _eob(_cl((t - StarTimeline.flyIn0) /
                (StarTimeline.flyIn1 - StarTimeline.flyIn0)));
          } else if (t < tl.flyOut0) {
            k = 1;
          } else {
            k = 1 - _eio(_cl((t - tl.flyOut0) / (tl.total - tl.flyOut0)));
          }
          final pos = Offset.lerp(corner, mid, k)!;
          final size = small + (big - small) * k;
          // Count and puff.
          var landed = 0;
          for (final l in tl.lands) {
            if (t >= l) landed++;
          }
          final count = landed == 0 ? tl.start : tl.tickValues[landed - 1];
          var puff = t >= tl.flyOut0 ? 1.0 : .0 + landed / tl.n;
          var sx = 1.0, sy = 1.0;
          if (landed > 0 && t < tl.flyOut0) {
            final since = t - tl.lands[landed - 1];
            if (since < 240) {
              final b = math.sin(math.pi * since / 240);
              puff += .08 * b;
              sx = 1 + .07 * b;
              sy = 1 - .07 * b;
            }
          }
          var rot = 0.0;
          if (t > tl.wiggle0 && t < tl.wiggle1) {
            rot = math.sin((t - tl.wiggle0) /
                    (tl.wiggle1 - tl.wiggle0) *
                    math.pi *
                    2) *
                .14;
          }
          // The "+N stars!" tag.
          final tagIn = _eob(_cl(t / 300));
          final tagOut = t > tl.flyOut0 ? _cl(1 - (t - tl.flyOut0) / 200) : 1.0;
          final tagScale = tagIn * tagOut;
          final tagY =
              k > 0 ? pos.dy - size * .62 - 26 : corner.dy + small * .7 + 20;
          final dim = .18 * k;
          final children = <Widget>[
            Positioned.fill(
                child:
                    ColoredBox(color: JamJotColors.ink.withValues(alpha: dim))),
          ];
          // Little stars pouring in from both sides.
          for (var i = 0; i < tl.n; i++) {
            final t0 = tl.lands[i] - StarTimeline.miniFlight;
            if (t < t0 || t >= tl.lands[i]) continue;
            final p = (t - t0) / StarTimeline.miniFlight;
            final fromLeft = i.isEven;
            final sx0 = fromLeft ? w * .08 : w * .92;
            final sy0 = mid.dy - big * .35;
            final target = Offset(mid.dx, mid.dy - big * .25);
            final x = sx0 + (target.dx - sx0) * p;
            final y = sy0 -
                big * .55 * math.sin(math.pi * p * .9) +
                (target.dy - sy0) * p * p;
            final s = 34 * (1 - .5 * p * p);
            children.add(Positioned(
                left: x - s / 2,
                top: y - s / 2,
                width: s,
                height: s,
                child: Transform.rotate(
                    angle: p * math.pi * 2 * (fromLeft ? 1 : -1),
                    child: Image.asset(
                        'assets/art/notestar/mini_star_${_minis[i % _minis.length]}.png',
                        gaplessPlayback: true))));
          }
          final sh = size * 236 / 239;
          children.add(Positioned(
            left: pos.dx - size / 2,
            top: pos.dy - sh / 2,
            child: Transform.rotate(
                angle: rot,
                child: StarStill(
                    balance: count,
                    width: size,
                    puff: puff,
                    squashX: sx,
                    squashY: sy)),
          ));
          if (tagScale > .01) {
            children.add(Positioned(
              left: 0,
              right: 0,
              top: tagY - 24,
              child: Center(
                child: Transform.scale(
                  scale: tagScale,
                  child: _EarnTag(earned: tl.earn),
                ),
              ),
            ));
          }
          return Stack(children: children);
        },
      );
    });
  }
}

class _EarnTag extends StatelessWidget {
  const _EarnTag({required this.earned});
  final int earned;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: JamJotColors.plum,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: JamJotColors.ink, width: 2.5),
          boxShadow: const [
            BoxShadow(color: JamJotColors.ink, offset: Offset(3, 4))
          ],
        ),
        child: Text('+$earned ${earned == 1 ? 'star' : 'stars'}!',
            style: const TextStyle(
                fontFamily: JamJotType.title,
                fontSize: 24,
                color: JamJotColors.ink,
                height: 1.1)),
      );
}
