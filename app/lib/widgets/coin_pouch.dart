import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import '../theme/jamjot_theme.dart';
import 'letter_avatar.dart' show artAsset;

/// The coin pouch: a little money-bag with the coin count splayed on it.
/// (Placeholder art — swap the 💰 for the real pouch illustration later.)
class CoinPouch extends ConsumerWidget {
  const CoinPouch({super.key, required this.studentId, this.big = false});
  final String studentId;
  final bool big;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(berryBalanceProvider(studentId)).valueOrNull;
    final size = big ? 54.0 : 36.0;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        artAsset('pouch', width: size, height: size),
        Positioned(
          bottom: big ? 2 : 0,
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: big ? 8 : 5, vertical: big ? 2 : 1),
            decoration: BoxDecoration(
              color: JamJotColors.ink,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              '${coins ?? '…'}',
              style: TextStyle(
                color: const Color(0xFFFFD66B),
                fontWeight: FontWeight.w800,
                fontSize: big ? 15 : 11,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// An inline coin price, e.g. "🪙 25".
class CoinPrice extends StatelessWidget {
  const CoinPrice(this.price, {super.key});
  final int price;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      artAsset('coin', width: 16, height: 16),
      const SizedBox(width: 3),
      Text('$price', style: const TextStyle(fontWeight: FontWeight.w800)),
    ]);
  }
}
