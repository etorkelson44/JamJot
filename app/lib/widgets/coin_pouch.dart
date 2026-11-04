import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state.dart';
import '../state/coin_rewards.dart';

/// The original supplied PNG is retained. Crop transparent padding in layout.
class JamCoin extends StatelessWidget {
  const JamCoin({super.key, this.size = 20});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: SizedBox.square(
          dimension: size,
          child: ClipRect(
            child: OverflowBox(
                maxWidth: size / .66,
                maxHeight: size / .66,
                child: Image.asset('assets/art/jam_coin.png',
                    width: size / .66,
                    height: size / .66,
                    fit: BoxFit.contain)),
          )));
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

/// Shared resting pot for Home, Practice, the market and adult child details.
class CoinPot extends ConsumerWidget {
  const CoinPot({super.key, required this.studentId, this.big = false});
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
                  title: const Text('Your coin pot'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset('assets/art/coin_pot.png',
                        width: 120, height: 120),
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
            'Coin pot, ${balance == null ? 'balance loading' : '$balance coins'}. Coin sound settings',
        child: ExcludeSemantics(
            child: Tooltip(
                message: 'Coin pot · sound settings',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: openSettings,
                  child: SizedBox(
                      width: size,
                      height: size + 8,
                      child: Stack(alignment: Alignment.topCenter, children: [
                        Image.asset('assets/art/coin_pot.png',
                            width: size, height: size),
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

/// Six representative coins fall behind the pile; the label gives the exact
/// award, including rewards larger than six. At rest there are no loose coins.
class FallingCoinPot extends StatefulWidget {
  const FallingCoinPot({super.key, required this.animate, this.size = 112});
  final bool animate;
  final double size;
  @override
  State<FallingCoinPot> createState() => _FallingCoinPotState();
}

class _FallingCoinPotState extends State<FallingCoinPot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant FallingCoinPot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animate) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
            width: widget.size,
            height: widget.size + 42,
            child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _controller.value;
                  return Stack(clipBehavior: Clip.hardEdge, children: [
                    if (widget.animate && t < 1)
                      for (var i = 0; i < 6; i++)
                        if (t >= i * .12 && t < i * .12 + .28)
                          Positioned(
                            top: -26 +
                                100 *
                                    math.pow((t - i * .12) / .28, 2).toDouble(),
                            left: widget.size / 2 -
                                13 +
                                (i.isEven ? -1 : 1) *
                                    13 *
                                    (1 - (t - i * .12) / .28),
                            child: Transform.rotate(
                                angle: (i.isEven ? 1 : -1) * t * 2,
                                child: const JamCoin(size: 26)),
                          ),
                    Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Image.asset('assets/art/coin_pot.png',
                            width: widget.size, height: widget.size)),
                  ]);
                })),
      );
}
