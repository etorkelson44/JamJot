import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state.dart';
import 'star_currency.dart';

/// The official JJ coin, trimmed tight — used anywhere a coin is shown.
class JamCoin extends StatelessWidget {
  const JamCoin({super.key, this.size = 20});
  final double size;
  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: StarIcon(size: size));
}

class CoinLabel extends StatelessWidget {
  const CoinLabel(this.label, {super.key, this.style, this.iconSize = 20});
  final String label;
  final TextStyle? style;
  final double iconSize;
  @override
  Widget build(BuildContext context) => Semantics(
      label: label,
      child: ExcludeSemantics(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
        JamCoin(size: iconSize),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: style)),
      ])));
}

class CoinPrice extends StatelessWidget {
  const CoinPrice(this.price, {super.key});
  final int price;
  @override
  Widget build(BuildContext context) => CoinLabel('$price stars',
      style: const TextStyle(fontWeight: FontWeight.w800));
}

/// The resting Jam Jar for the market and adult child details (kids see the
/// corner jar beside their profile icon instead): the closed jar, with the
/// coins visible inside when it isn't empty, and the balance on a badge
/// underneath. Display only; sound choices belong to the caregiver.
class JamJar extends ConsumerWidget {
  const JamJar({super.key, required this.studentId, this.big = false});
  final String studentId;
  final bool big;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(berryBalanceProvider(studentId));
    final balance = value.valueOrNull;
    final size = big ? 84.0 : 64.0;
    return Semantics(
        label:
            'star count, ${balance == null ? 'balance loading' : '$balance coins'}',
        child: ExcludeSemantics(
            child: SizedBox(
                width: size,
                height: size * 236 / 239 + 4,
                child: Align(
                    alignment: Alignment.topCenter,
                    child: JarStill(balance: balance, width: size)))));
  }
}

/// The closed jar as a still image, with the coin count painted on the
/// label coin in the same lettering that spells "JAM" (shown while the count
/// is unknown). A quiet pile of coins shows in the glass once there's
/// something saved up.
class JarStill extends StatelessWidget {
  const JarStill({super.key, required this.balance, required this.width});
  final int? balance;
  final double width;
  @override
  Widget build(BuildContext context) =>
      // NoteStar (2026-11-16): the star with its count replaces the jar.
      StarStill(balance: balance, width: width);
}

/// The little jar in the corner, where the earn-coins flight starts and
/// ends: it hides itself while the flight is on screen.
final jarFlightActive = ValueNotifier<bool>(false);

/// Screen rectangle of the corner jar, reported by whoever draws it, so the
/// flight can start and end exactly there.
Rect? jarCornerRect;

class CornerJarReporter extends StatefulWidget {
  const CornerJarReporter({super.key, required this.child});
  final Widget child;
  @override
  State<CornerJarReporter> createState() => _CornerJarReporterState();
}

class _CornerJarReporterState extends State<CornerJarReporter> {
  Rect? _mine;
  @override
  void dispose() {
    if (identical(jarCornerRect, _mine)) jarCornerRect = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is RenderBox && box.hasSize && box.attached) {
        _mine = box.localToGlobal(Offset.zero) & box.size;
        jarCornerRect = _mine;
      }
    });
    return ValueListenableBuilder<bool>(
        valueListenable: jarFlightActive,
        builder: (context, flying, child) =>
            Opacity(opacity: flying ? 0 : 1, child: child),
        child: widget.child);
  }
}

/// The earning moment. Animated, it is the full-screen flight: the jar
/// swings from the corner to the middle, the lid comes off, the coins drop
/// in while the label count ticks up, and it flies home. Not animated (reduce
/// motion), it is a still jar showing the new total.
class FallingCoinJar extends StatelessWidget {
  const FallingCoinJar({
    super.key,
    required this.animate,
    this.size = 112,
    this.startCount = 0,
    this.earned = 1,
    this.cornerCenter,
    this.cornerWidth = 56,
    this.onDone,
  });
  final bool animate;
  final double size;
  final int startCount, earned;
  final Offset? cornerCenter;
  final double cornerWidth;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    if (!animate) {
      return ExcludeSemantics(
          child: StarStill(balance: startCount + earned, width: size));
    }
    return StarFlight(
        startCount: startCount,
        earned: earned,
        cornerCenter: cornerCenter,
        cornerWidth: cornerWidth,
        onDone: onDone);
  }
}
