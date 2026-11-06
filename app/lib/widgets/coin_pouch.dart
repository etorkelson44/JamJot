import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state.dart';
import '../state/coin_rewards.dart';
import 'jam_jar_art.dart';

/// The official JJ coin, trimmed tight — used anywhere a coin is shown.
class JamCoin extends StatelessWidget {
  const JamCoin({super.key, this.size = 20});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: Image.asset('assets/art/jam_coin.png',
          width: size, height: size, fit: BoxFit.contain));
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
  Widget build(BuildContext context) => CoinLabel('$price coins',
      style: const TextStyle(fontWeight: FontWeight.w800));
}

/// A little pile of coins resting inside the glass, sized to sit in the
/// clear band under the JAM label. Shown only when the jar isn't empty.
class _CoinsInside extends StatelessWidget {
  const _CoinsInside({required this.jarWidth});
  final double jarWidth;
  @override
  Widget build(BuildContext context) {
    final c = jarWidth * 0.22;
    return Opacity(
      opacity: 0.88, // a touch dimmed, as if seen through the glass
      child: SizedBox(
        width: jarWidth * 0.62,
        height: c * 1.5,
        child: Stack(alignment: Alignment.bottomCenter, children: [
          Positioned(left: 0, bottom: 0, child: JamCoin(size: c)),
          Positioned(right: 0, bottom: 0, child: JamCoin(size: c)),
          Positioned(
              bottom: c * 0.45,
              child: Transform.rotate(angle: -0.2, child: JamCoin(size: c))),
        ]),
      ),
    );
  }
}

/// The resting Jam Jar for Home, Practice, the market and adult child
/// details: the closed jar, with the coins visible inside when it isn't
/// empty, and the balance on a badge underneath.
class JamJar extends ConsumerWidget {
  const JamJar({super.key, required this.studentId, this.big = false});
  final String studentId;
  final bool big;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(berryBalanceProvider(studentId));
    final balance = value.valueOrNull;
    final size = big ? 84.0 : 64.0;
    void openSettings() => showDialog<void>(
        context: context,
        builder: (_) => Consumer(
            builder: (context, ref, child) => AlertDialog(
                  title: const Text('Your Jam Jar'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    JarStill(balance: balance, width: 110),
                    const SizedBox(height: 8),
                    Text(balance == null
                        ? 'Loading your coins…'
                        : '$balance coins'),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Coin sounds'),
                        subtitle:
                            const Text('A little jingle when you earn coins.'),
                        value: ref.watch(coinSoundsProvider),
                        onChanged:
                            ref.read(coinSoundsProvider.notifier).setEnabled),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'))
                  ],
                )));
    return Semantics(
        onTap: openSettings,
        button: true,
        label:
            'Jam Jar, ${balance == null ? 'balance loading' : '$balance coins'}. Coin sound settings',
        child: ExcludeSemantics(
            child: Tooltip(
                message: 'Jam Jar · sound settings',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: openSettings,
                  child: SizedBox(
                      width: size,
                      height: size * kJarImageH / kJarImageW + 4,
                      child: Align(
                          alignment: Alignment.topCenter,
                          child: JarStill(balance: balance, width: size))),
                ))));
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
  Widget build(BuildContext context) {
    final height = width * kJarImageH / kJarImageW;
    final count = balance;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(children: [
        Image.asset('assets/art/jar/closed.webp',
            width: width, height: height, fit: BoxFit.fill),
        if (count != null && count > 0)
          // The coins live in the clear glass BELOW the label: this clip is
          // that band, so a tall pile disappears behind the label instead
          // of floating in front of it.
          Positioned(
            left: width * 0.12,
            right: width * 0.12,
            top: height * 0.741,
            bottom: height * 0.065,
            child: ClipRect(
              child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _CoinsInside(jarWidth: width)),
            ),
          ),
        positionedJarCount(count == null ? 'JAM' : '$count', width),
      ]),
    );
  }
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
          child: JarStill(balance: startCount + earned, width: size));
    }
    return JarFlight(
        startCount: startCount,
        earned: earned,
        cornerCenter: cornerCenter,
        cornerWidth: cornerWidth,
        onDone: onDone);
  }
}
