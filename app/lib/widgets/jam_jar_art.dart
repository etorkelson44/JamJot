import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Jam Jar art. Everything here is laid out on a 1000 x 1000 "stage" so the
/// still jar and the coin-earning flight share one set of coordinates:
/// the closed jar image is 620 wide at (190, 120), and the label count is
/// centered at (400, 558).

/// Width of each count glyph image in pixels (assets are 1.2 px per unit).
const _glyphPx = <String, double>{
  '0': 128,
  '1': 83,
  '2': 111,
  '3': 112,
  '4': 132,
  '5': 111,
  '6': 119,
  '7': 111,
  '8': 121,
  '9': 119,
  'JAM': 380,
};

const double kJarImageW = 620, kJarImageH = 762.5;
const double _countCx = 400, _countCy = 558, _countRegion = 321;
const double _glyphH = 150, _glyphGap = 16;

/// The count painted on the label coin, in the same chunky lettering that
/// spells "JAM" on a jar with no count. [text] is digits, or 'JAM'.
/// [unit] is pixels per stage unit.
class JarCount extends StatelessWidget {
  const JarCount({super.key, required this.text, required this.unit});
  final String text;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final keys = text == 'JAM'
        ? const ['JAM']
        : text.split('').where(_glyphPx.containsKey).toList();
    final h = _glyphH * unit;
    final kids = <Widget>[];
    for (final k in keys) {
      final w = _glyphPx[k]! / 1.2 * unit;
      final file = k == 'JAM' ? 'jam' : 'd$k';
      kids.add(SizedBox(
          width: w - _glyphGap * unit,
          height: h,
          child: OverflowBox(
              minWidth: w,
              maxWidth: w,
              minHeight: h,
              maxHeight: h,
              child: Image.asset('assets/art/jar/$file.webp',
                  width: w,
                  height: h,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium))));
    }
    return SizedBox(
        width: _countRegion * unit,
        height: h,
        child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
                padding: EdgeInsets.symmetric(horizontal: _glyphGap / 2 * unit),
                child: Row(mainAxisSize: MainAxisSize.min, children: kids))));
  }
}

/// Where the count sits on a jar image of the given width.
Widget positionedJarCount(String text, double width) {
  final u = width / kJarImageW;
  return Positioned(
      left: (_countCx - 190 - _countRegion / 2) * u,
      top: (_countCy - 120 - _glyphH / 2) * u,
      child: JarCount(text: text, unit: u));
}

class _Coin {
  _Coin(this.spawn, this.d, this.x0, this.xm, this.xl, this.yl, this.rot0,
      this.spin, this.rotF, this.flips, this.inc, this.um)
      : tick = spawn + d * um;
  final double spawn, d, x0, xm, xl, yl, rot0, spin, rotF, flips, um, tick;
  final int inc;
  static const y0 = -215.0;
}

/// The whole earn-coins flight as a pure function of time (milliseconds):
/// the jar swings from its corner to the middle, opens, coins pile in while
/// the label count ticks up, the lid goes back on, and the jar flies home.
class JarTimeline {
  JarTimeline({required this.start, required int earn})
      : earn = math.max(1, earn) {
    n = math.min(this.earn, 16);
    final r = math.Random(7 + this.earn * 31 + start);
    stagger = math.min(105.0, 1500.0 / n);
    lastLand = drop0 + (n - 1) * stagger + _d;
    lidBack0 = lastLand + 200;
    lidBack1 = lastLand + 720;
    hold = lidBack1 + 300;
    flyOut1 = hold + 950;
    total = flyOut1 + 700;
    final base = this.earn ~/ n, rem = this.earn - base * n;
    var run = start;
    for (var i = 0; i < n; i++) {
      final spawn = drop0 + i * stagger;
      final yl = 772 - math.min(i, 10) * 6 + (r.nextDouble() - .5) * 14;
      final um = math.sqrt((_mouthY - _Coin.y0) / (yl - _Coin.y0));
      final d = _d + r.nextDouble() * 90;
      final x0 = 610 + r.nextDouble() * 70;
      final xm = 498 + (r.nextDouble() - .5) * 110;
      final xl = 335 + r.nextDouble() * 330;
      final rot0 = r.nextDouble() * 360;
      final spin = (r.nextBool() ? -1 : 1) * (400 + r.nextDouble() * 400);
      final rotF = (r.nextDouble() - .5) * 40;
      final flips = 2 + r.nextDouble() * 2;
      run += base + (i < rem ? 1 : 0);
      coins.add(_Coin(spawn, d, x0, xm, xl, yl, rot0, spin, rotF, flips,
          base + (i < rem ? 1 : 0), um));
      tickValues.add(run);
    }
  }

  static const flyIn0 = 450.0, flyIn1 = 1350.0;
  static const wobble0 = 1350.0, wobble1 = 1520.0;
  static const lift0 = 1520.0, lift1 = 2120.0;
  static const drop0 = 2250.0;
  static const _d = 720.0, _mouthY = 254.0;

  final int start, earn;
  late final int n;
  late final double stagger, lastLand, lidBack0, lidBack1, hold, flyOut1, total;
  final coins = <_Coin>[];
  final tickValues = <int>[];

  double get flyOut0 => hold;

  /// Milliseconds (from the start of the flight) at which each coin crosses
  /// the mouth of the jar: when each coin blip should play.
  List<int> get tickDelays => [for (final c in coins) c.tick.round()];

  int get endCount => start + earn;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
double _clamp(double x, [double a = 0, double b = 1]) =>
    math.min(b, math.max(a, x));
double _eio(double t) =>
    t < .5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;
double _eo(double t) => 1 - math.pow(1 - t, 3).toDouble();
double _eob(double t) {
  const c1 = 1.4, c3 = c1 + 1;
  return 1 +
      c3 * math.pow(t - 1, 3).toDouble() +
      c1 * math.pow(t - 1, 2).toDouble();
}

/// One frame of the flight, drawn on the 1000 x 1000 stage.
class JarFlightStage extends StatelessWidget {
  const JarFlightStage({super.key, required this.timeline, required this.t});
  final JarTimeline timeline;
  final double t;

  static const _labelBottom = 685.0, _mouthY = 254.0;

  Widget _coin(double cx, double cy, double rotDeg, double sx) => Positioned(
      left: cx - 32,
      top: cy - 32,
      width: 64,
      height: 65.3,
      child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(rotDeg * math.pi / 180)
            ..scaleByDouble(sx, 1.0, 1.0, 1.0),
          child: Image.asset('assets/art/jar/coin.webp', fit: BoxFit.fill)));

  @override
  Widget build(BuildContext context) {
    final tl = timeline;
    final behind = <Widget>[], band = <Widget>[], front = <Widget>[];
    for (final c in tl.coins) {
      final u = (t - c.spawn) / c.d;
      if (u < 0) continue;
      double cx, cy, rot, sx;
      if (u >= 1) {
        cx = c.xl;
        cy = c.yl;
        rot = c.rotF;
        sx = 1;
      } else {
        cy = _Coin.y0 + (c.yl - _Coin.y0) * u * u;
        cx = u < c.um
            ? _lerp(c.x0, c.xm, u / c.um)
            : _lerp(c.xm, c.xl, math.pow((u - c.um) / (1 - c.um), 2).toDouble());
        rot = c.rot0 * .15 + c.spin * u * .25;
        sx = math.max(.32, math.cos(u * c.flips * math.pi).abs());
      }
      if (cy >= _labelBottom - 4) {
        final w = u >= 1 ? 1.0 : _clamp((cy - _labelBottom) / (c.yl - _labelBottom));
        rot = _lerp(rot, c.rotF, w);
        sx = _lerp(sx, 1, w);
        band.add(_coin(cx - 255, cy - _labelBottom, rot, sx));
      } else if (cy >= _mouthY) {
        behind.add(_coin(cx, cy, rot, sx));
      } else {
        front.add(_coin(cx, cy, rot, sx));
      }
    }

    // ----- lid & jar state -----
    final open = t >= JarTimeline.lift0 && t < tl.lidBack1;
    double l = 0; // 0 seated .. 1 hovering
    if (t >= JarTimeline.lift0 && t < JarTimeline.lift1) {
      l = _eo((t - JarTimeline.lift0) / (JarTimeline.lift1 - JarTimeline.lift0));
    } else if (t >= JarTimeline.lift1 && t < tl.lidBack0) {
      l = 1;
    } else if (t >= tl.lidBack0 && t < tl.lidBack1) {
      l = 1 - _eio((t - tl.lidBack0) / (tl.lidBack1 - tl.lidBack0));
    }
    final bob = l >= 1 ? math.sin(t / 260) * 4 : 0.0;
    final fade = _clamp((l - .72) / .22);

    // ----- count -----
    var value = tl.start;
    var lastTick = -1e9;
    for (var i = 0; i < tl.coins.length; i++) {
      if (t >= tl.coins[i].tick) {
        value = tl.tickValues[i];
        lastTick = tl.coins[i].tick;
      }
    }
    final since = t - lastTick;
    final pulse = since >= 0 && since < 260 ? math.sin(since / 260 * math.pi) : 0.0;
    final fin = t >= tl.flyOut1 && t < tl.flyOut1 + 600
        ? math.sin((t - tl.flyOut1) / 600 * math.pi)
        : 0.0;
    final bandOpacity = t >= tl.lidBack0
        ? 1 - _clamp((t - tl.lidBack0) / (tl.lidBack1 - tl.lidBack0))
        : 1.0;

    return SizedBox(
        width: 1000,
        height: 1000,
        child: Stack(clipBehavior: Clip.none, children: [
          ...behind,
          if (open)
            Positioned(
                left: 190,
                top: 207.5,
                width: 615,
                child: Image.asset('assets/art/jar/open.webp',
                    fit: BoxFit.fitWidth))
          else
            Positioned(
                left: 190,
                top: 120,
                width: 620,
                child: Image.asset('assets/art/jar/closed.webp',
                    fit: BoxFit.fitWidth)),
          Positioned(
              left: 255,
              top: _labelBottom,
              width: 490,
              height: 150,
              child: Opacity(
                  opacity: bandOpacity,
                  child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.elliptical(150, 100),
                          bottomRight: Radius.elliptical(150, 100)),
                      child: Stack(clipBehavior: Clip.none, children: band)))),
          ...front,
          if (open && fade < 1)
            Positioned(
                left: 233.5,
                top: 122.5,
                width: 532.5,
                child: Opacity(
                    opacity: 1 - fade,
                    child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..translateByDouble(_lerp(0, 364 - 499.5, l),
                              _lerp(0, -11 - 221, l) + bob, 0, 1)
                          ..rotateZ(_lerp(0, -44, l) * math.pi / 180)
                          ..scaleByDouble(1.0, _lerp(1, .78, l), 1.0, 1.0),
                        child: Image.asset('assets/art/jar/lid_seated.webp',
                            fit: BoxFit.fitWidth)))),
          if (open && fade > 0)
            Positioned(
                left: 125.3,
                top: -239.2 + bob,
                width: 458.7,
                child: Opacity(
                    opacity: fade,
                    child: Image.asset('assets/art/jar/lid_hover.webp',
                        fit: BoxFit.fitWidth))),
          Positioned(
              left: _countCx - _countRegion / 2,
              top: _countCy - _glyphH / 2,
              child: Transform.scale(
                  scale: 1 + .22 * pulse + .15 * fin,
                  child: JarCount(text: '$value', unit: 1))),
        ]));
  }
}

/// Plays the flight full screen over the app: a dimmed backdrop, the jar
/// swinging from [cornerCenter] (where the little jar lives) to the middle
/// and back, and a "+N coins!" caption. Ignores touches.
class JarFlight extends StatefulWidget {
  const JarFlight({
    super.key,
    required this.startCount,
    required this.earned,
    required this.cornerCenter,
    required this.cornerWidth,
    this.onDone,
  });
  final int startCount, earned;
  final Offset? cornerCenter;
  final double cornerWidth;
  final VoidCallback? onDone;
  @override
  State<JarFlight> createState() => _JarFlightState();
}

class _JarFlightState extends State<JarFlight>
    with SingleTickerProviderStateMixin {
  late final JarTimeline _tl =
      JarTimeline(start: widget.startCount, earn: widget.earned);
  late final AnimationController _c = AnimationController(
      vsync: this, duration: Duration(milliseconds: _tl.total.round()))
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
    final tl = _tl;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final s = w / 390;
      final corner = widget.cornerCenter ?? Offset(w - 44, 56);
      final cornerK = (widget.cornerWidth / kJarImageW).clamp(0.05, 0.4).toDouble();
      final centerW = math.min(w * 0.668, 300.0);
      final centerK = centerW / kJarImageW;
      final center = Offset(w / 2, h * 0.5);
      final text = Theme.of(context).textTheme;
      return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value * tl.total;
            var p = 0.0; // 0 = corner, 1 = center
            if (t >= JarTimeline.flyIn0 && t < JarTimeline.flyIn1) {
              p = (t - JarTimeline.flyIn0) /
                  (JarTimeline.flyIn1 - JarTimeline.flyIn0);
            } else if (t >= JarTimeline.flyIn1 && t < tl.flyOut0) {
              p = 1;
            } else if (t >= tl.flyOut0 && t < tl.flyOut1) {
              p = 1 - (t - tl.flyOut0) / (tl.flyOut1 - tl.flyOut0);
            }
            final e = _eio(p), arc = math.sin(math.pi * p);
            final k = _lerp(cornerK, centerK,
                p < 1 && t < tl.flyOut0 ? _clamp(_eob(p), 0, 1.03) : e);
            final x = _lerp(corner.dx, center.dx, e) - 70 * s * arc;
            final y = _lerp(corner.dy, center.dy, e);
            var tilt = -7 * arc;
            if (t >= JarTimeline.wobble0 && t < JarTimeline.wobble1) {
              final wv = (t - JarTimeline.wobble0) /
                  (JarTimeline.wobble1 - JarTimeline.wobble0);
              tilt += math.sin(wv * math.pi * 4) * 2.5;
            }
            final caption = _clamp((t - JarTimeline.flyIn1) / 300) *
                (1 - _clamp((t - tl.flyOut0) / 250));
            return Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                  child: ColoredBox(
                      color: Color.fromRGBO(38, 50, 62, .55 * _clamp(e)))),
              Positioned(
                  left: 0,
                  top: 0,
                  width: 1000,
                  height: 1000,
                  child: Transform(
                      alignment: Alignment.topLeft,
                      transform: Matrix4.identity()
                        ..translateByDouble(x - k * 499, y - k * 500, 0, 1)
                        ..scaleByDouble(k, k, 1, 1),
                      child: Transform.rotate(
                          angle: tilt * math.pi / 180,
                          child: ExcludeSemantics(
                              child: JarFlightStage(timeline: tl, t: t))))),
              Positioned(
                  left: 16,
                  right: 16,
                  top: center.dy + centerW * kJarImageH / kJarImageW / 2 + 12,
                  child: Opacity(
                      opacity: caption,
                      child: Text('+${widget.earned} coins!',
                          textAlign: TextAlign.center,
                          style: (text.headlineMedium ?? const TextStyle())
                              .copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  shadows: const [
                                Shadow(blurRadius: 6, color: Colors.black54)
                              ])))),
            ]);
          });
    });
  }
}
