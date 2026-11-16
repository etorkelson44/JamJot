import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../state/app_state.dart';
import '../theme/jamjot_theme.dart';

/// NoteStar paper-cut art (2026-11-15). Erika's piano character, cut-paper
/// accents and the fan count. Art lives in assets/art/notestar/.
enum PianoPose { waving, pointing, oneHandWave, kick }

enum PianoMove { danceWave, danceDisco, danceKickline, celebrate }

const _pianoPoseAsset = {
  PianoPose.waving: 'assets/art/notestar/piano_waving.png',
  PianoPose.pointing: 'assets/art/notestar/piano_pointing.png',
  PianoPose.oneHandWave: 'assets/art/notestar/piano_one_hand_wave.png',
  PianoPose.kick: 'assets/art/notestar/piano_kick.png',
};
const _pianoMoveAsset = {
  PianoMove.danceWave: 'assets/art/notestar/piano_dance_wave.webp',
  PianoMove.danceDisco: 'assets/art/notestar/piano_dance_disco.webp',
  PianoMove.danceKickline: 'assets/art/notestar/piano_dance_kickline.webp',
  PianoMove.celebrate: 'assets/art/notestar/piano_celebrate.webp',
};

/// The piano character, standing still in one of Erika's poses.
class PianoPal extends StatelessWidget {
  const PianoPal(
      {super.key, this.pose = PianoPose.waving, this.width = 180, this.label});
  final PianoPose pose;
  final double width;
  final String? label;
  @override
  Widget build(BuildContext context) => Image.asset(_pianoPoseAsset[pose]!,
      width: width,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      semanticLabel: label ?? 'The NoteStar piano',
      errorBuilder: (_, __, ___) => SizedBox(width: width, height: width * .8));
}

/// The piano dancing or celebrating (animated, loops forever).
class PianoDance extends StatelessWidget {
  const PianoDance(
      {super.key, this.move = PianoMove.danceWave, this.width = 180});
  final PianoMove move;
  final double width;
  @override
  Widget build(BuildContext context) {
    // Respect "reduce motion": show a still pose instead.
    if (MediaQuery.of(context).disableAnimations) {
      return PianoPal(
          pose: move == PianoMove.celebrate
              ? PianoPose.pointing
              : PianoPose.waving,
          width: width);
    }
    return Image.asset(_pianoMoveAsset[move]!,
        width: width,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        semanticLabel: 'The NoteStar piano dancing',
        errorBuilder: (_, __, ___) => PianoPal(width: width));
  }
}

/// A small cut-paper decoration (star, moon, dot).
class PaperAccent extends StatelessWidget {
  const PaperAccent(this.name, {super.key, this.size = 40});
  final String
      name; // e.g. 'star_big_pink', 'moon_blue', 'dot_lime'
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: Image.asset('assets/art/notestar/$name.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => SizedBox(width: size, height: size)));
}

/// NoteStar fans: an ongoing count that grows as songs and practices are
/// finished. It doesn't buy anything; it's just fun to watch it climb.
class FanCount extends ConsumerWidget {
  const FanCount({super.key, required this.studentId, this.big = false});
  final String studentId;
  final bool big;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fans = ref.watch(fanTotalProvider(studentId)).valueOrNull ?? 0;
    final n = NumberFormat.decimalPattern().format(fans);
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$n fans',
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: big ? 16 : 12, vertical: big ? 10 : 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: JamJotColors.ink, width: 2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(
              child: Image.asset('assets/art/notestar/fan_alien.png',
                  width: big ? 34 : 24, height: big ? 34 : 24)),
          const SizedBox(width: 6),
          Text(n,
              style: (big ? text.headlineSmall : text.titleMedium)?.copyWith(
                  fontFamily: JamJotType.display, letterSpacing: .5)),
          const SizedBox(width: 6),
          Text(fans == 1 ? 'fan' : 'fans',
              style: text.titleSmall?.copyWith(fontFamily: JamJotType.title)),
        ]),
      ),
    );
  }
}

/// True when one of these instruments is a piano or keyboard. The piano
/// character only shows up on piano pages (founder-directed 2026-11-15).
bool playsPiano(Iterable<String?> instruments) => instruments.any((i) {
      final s = (i ?? '').toLowerCase();
      return s.contains('piano') ||
          s.contains('keyboard') ||
          s.contains('keys');
    });

/// The NoteStar star-note logo with a gentle bob, for pages that aren't
/// about one instrument (loading, calendar, errors, Home). Still when
/// "reduce motion" is on.
class StarBounce extends StatefulWidget {
  const StarBounce({super.key, this.size = 120, this.animate = true});
  final double size;
  final bool animate;
  @override
  State<StarBounce> createState() => _StarBounceState();
}

class _StarBounceState extends State<StarBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = !widget.animate || MediaQuery.of(context).disableAnimations;
    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset('assets/art/notestar_logo.png',
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        semanticLabel: 'NoteStar',
        errorBuilder: (_, __, ___) =>
            SizedBox(width: widget.size, height: widget.size));
    return AnimatedBuilder(
      animation: _c,
      child: logo,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(
            offset: Offset(0, -widget.size * .06 * t),
            child: Transform.rotate(angle: (t - .5) * .12, child: child));
      },
    );
  }
}

/// The star-note logo with paper accents around it: the "no character"
/// picture for empty states and Home.
class StarCluster extends StatelessWidget {
  const StarCluster({super.key, this.width = 180, this.animate = false});
  final double width;
  final bool animate;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: width * .9,
        child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                  left: 0,
                  top: width * .08,
                  child: PaperAccent('moon_blue', size: width * .2)),
              Positioned(
                  right: 0,
                  top: 0,
                  child: PaperAccent('star_big_pink', size: width * .2)),
              Positioned(
                  right: width * .06,
                  bottom: 0,
                  child: PaperAccent('star_small_violet', size: width * .14)),
              Positioned(
                  left: width * .1,
                  bottom: width * .04,
                  child: PaperAccent('dot_pink', size: width * .08)),
              StarBounce(size: width * .7, animate: animate),
            ]),
      );
}

/// The kid's instrument character when it exists (only the piano so far),
/// otherwise the NoteStar star. [dancing] uses [move]; otherwise [pose].
class InstrumentPal extends StatelessWidget {
  const InstrumentPal({
    super.key,
    required this.instruments,
    this.pose = PianoPose.waving,
    this.move = PianoMove.danceWave,
    this.dancing = false,
    this.width = 180,
  });
  final Iterable<String?> instruments;
  final PianoPose pose;
  final PianoMove move;
  final bool dancing;
  final double width;
  @override
  Widget build(BuildContext context) {
    if (playsPiano(instruments)) {
      return dancing
          ? PianoDance(move: move, width: width)
          : PianoPal(pose: pose, width: width);
    }
    return StarCluster(width: width, animate: dancing);
  }
}
