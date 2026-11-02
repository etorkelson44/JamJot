import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/jamjot_theme.dart';

/// The pun stickers: drawn art + its phrase. Appears at the right moments
/// all over the app. (Art is JamJot-drawn placeholder — final art swaps in
/// by file name.)
class Sticker {
  const Sticker(this.asset, this.phrase);
  final String asset;
  final String phrase;
}

const stickers = <String, Sticker>{
  'well_done': Sticker('sticker_well_done', 'Berry well done!'),
  'lets_jam': Sticker('sticker_lets_jam', "Let's jam!"),
  'beleafing': Sticker('sticker_beleafing', "Don't stop be-leafing!"),
  'green_berry': Sticker('sticker_green_berry', 'Every berry starts green.'),
  'jam_tastic': Sticker('sticker_jam_tastic', 'Jam-tastic!'),
  'grape_job': Sticker('sticker_grape_job', 'Grape job!'),
  'plum_perfect': Sticker('sticker_plum_perfect', 'Plum perfect!'),
  'berry_rich': Sticker('sticker_berry_rich', 'Berry rich!'),
};

/// Which stickers fit which moment.
const successStickers = ['well_done', 'grape_job', 'plum_perfect', 'jam_tastic'];
const keepGoingStickers = ['beleafing', 'green_berry'];

final _rng = Random();
String randomOf(List<String> keys) => keys[_rng.nextInt(keys.length)];

/// The sticker as a widget (art + phrase) for embedding in dialogs/screens.
class StickerBadge extends StatelessWidget {
  const StickerBadge(this.key_, {super.key, this.size = 110});
  final String key_;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = stickers[key_];
    if (s == null) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SvgPicture.asset('assets/art/${s.asset}.svg',
          width: size, height: size),
      const SizedBox(height: 2),
      Text(
        s.phrase,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size * 0.16,
          fontWeight: FontWeight.w800,
          color: JamJotColors.ink,
        ),
      ),
    ]);
  }
}

/// Pops a sticker over the whole screen with a happy bounce, then fades it
/// away by itself. Never blocks taps.
void popSticker(BuildContext context, String key, {int ms = 1500}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final s = stickers[key];
  if (overlay == null || s == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: ms),
          onEnd: () => entry.remove(),
          builder: (context, t, child) {
            // Bounce in fast, hold, fade out at the end.
            final appear = Curves.elasticOut.transform((t * 3).clamp(0, 1));
            final fade = t > 0.8 ? (1 - (t - 0.8) / 0.2) : 1.0;
            return Opacity(
              opacity: fade.clamp(0, 1),
              child: Transform.scale(scale: appear, child: child),
            );
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF6),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: JamJotColors.ink, width: 3),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 14,
                      offset: Offset(0, 6)),
                ],
              ),
              child: StickerBadge(key, size: 120),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
}
