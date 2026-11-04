import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state.dart';
import '../state/coin_rewards.dart';

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
    final size = big ? 70.0 : 52.0;
    void openSettings() => showDialog<void>(
        context: context,
        builder: (_) => Consumer(
            builder: (context, ref, child) => AlertDialog(
                  title: const Text('Your Jam Jar'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    JarStill(balance: balance ?? 0, width: 110),
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
                      height: size * 1.42 + 10,
                      child: Stack(alignment: Alignment.topCenter, children: [
                        JarStill(balance: balance ?? 0, width: size),
                        Positioned(
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF252220),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFFFD66B))),
                              child: Text('${balance ?? '…'}',
                                  style: TextStyle(
                                      color: const Color(0xFFFFD66B),
                                      fontWeight: FontWeight.w800,
                                      fontSize: big ? 15 : 12)),
                            )),
                      ])),
                ))));
  }
}

/// The closed jar as a still image: empty glass at zero coins, a quiet pile
/// inside once there's something saved up.
class JarStill extends StatelessWidget {
  const JarStill({super.key, required this.balance, required this.width});
  final int balance;
  final double width;
  @override
  Widget build(BuildContext context) {
    final height = width * 793 / 560;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(children: [
        Image.asset('assets/art/jar_closed.png',
            width: width, height: height, fit: BoxFit.contain),
        if (balance > 0)
          Align(
              alignment: const Alignment(0, 0.72),
              child: _CoinsInside(jarWidth: width)),
      ]),
    );
  }
}

/// The earning moment: the lid pops off, a few coins drop into the open jar,
/// and the lid settles back on. The label gives the exact award.
class FallingCoinJar extends StatefulWidget {
  const FallingCoinJar({super.key, required this.animate, this.size = 112});
  final bool animate;
  final double size;
  @override
  State<FallingCoinJar> createState() => _FallingCoinJarState();
}

class _FallingCoinJarState extends State<FallingCoinJar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant FallingCoinJar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animate) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final jarH = w * 793 / 560; // closed-jar aspect
    final openH = w * 743 / 560; // open-jar aspect
    return ExcludeSemantics(
      child: SizedBox(
          width: w * 1.5,
          height: jarH + 46,
          child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                final jarOpen = widget.animate && t >= 0.08 && t < 0.92;
                // Lid flight: off and up-left, hovering tilted, then back.
                double lift; // 0 = seated, 1 = hovering
                if (!widget.animate) {
                  lift = 0;
                } else if (t < 0.08) {
                  lift = 0;
                } else if (t < 0.25) {
                  lift = Curves.easeOut.transform((t - 0.08) / 0.17);
                } else if (t < 0.72) {
                  lift = 1;
                } else if (t < 0.92) {
                  lift = 1 - Curves.easeIn.transform((t - 0.72) / 0.20);
                } else {
                  lift = 0;
                }
                return Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Falling coins, aimed at the jar mouth, behind the lid.
                      if (widget.animate && t >= 0.22 && t < 0.78)
                        for (var i = 0; i < 6; i++)
                          if (t >= 0.22 + i * .08 && t < 0.22 + i * .08 + .22)
                            Positioned(
                              bottom: jarH +
                                  26 -
                                  (jarH * 0.55 + 26) *
                                      math
                                          .pow((t - 0.22 - i * .08) / .22, 2)
                                          .toDouble(),
                              child: Transform.translate(
                                offset: Offset((i.isEven ? -1 : 1) * 7.0, 0),
                                child: Transform.rotate(
                                    angle: (i.isEven ? 1 : -1) * t * 3,
                                    child: JamCoin(size: w * 0.24)),
                              ),
                            ),
                      // The jar itself: open while the lid is off.
                      if (jarOpen)
                        Image.asset('assets/art/jar_open.png',
                            width: w, height: openH, fit: BoxFit.contain)
                      else
                        Image.asset('assets/art/jar_closed.png',
                            width: w, height: jarH, fit: BoxFit.contain),
                      // The lid, flying off and back on.
                      if (lift > 0.01)
                        Positioned(
                          bottom: jarH - w * 0.18 + lift * w * 0.55,
                          child: Transform.translate(
                            offset: Offset(-lift * w * 0.42, 0),
                            child: Transform.rotate(
                              angle: -lift * 0.32,
                              child: Image.asset('assets/art/jar_lid.png',
                                  width: w * 0.78, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                    ]);
              })),
    );
  }
}
