import 'package:flutter/material.dart';

/// One place that decides how an instrument is drawn.
///
/// Piano and keyboard use the founder's own piano drawing
/// (assets/art/icon_piano.png) everywhere — never an emoji. Other
/// instruments keep their emoji until they get drawn art.
const _instrumentEmoji = <String, String>{
  'piano': '🎹',
  'keyboard': '🎹',
  'violin': '🎻',
  'viola': '🎻',
  'cello': '🎻',
  'bass': '🎻',
  'guitar': '🎸',
  'ukulele': '🎸',
  'drums': '🥁',
  'percussion': '🥁',
  'voice': '🎤',
  'singing': '🎤',
  'flute': '🪈',
  'recorder': '🪈',
  'clarinet': '🪈',
  'saxophone': '🎷',
  'trumpet': '🎺',
  'trombone': '🎺',
  'harp': '🪕',
  'banjo': '🪕',
};

/// The emoji for an instrument name ('🎵' when unknown or null).
String instrumentEmoji(String? instrument) {
  if (instrument == null) return '🎵';
  final key = instrument.trim().toLowerCase();
  for (final entry in _instrumentEmoji.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return '🎵';
}

bool isPianoInstrument(String? instrument) => instrumentEmoji(instrument) == '🎹';

/// The founder's piano drawing, sized like an icon.
class PianoIcon extends StatelessWidget {
  const PianoIcon({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/art/icon_piano.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
}

/// An icon for an instrument: the piano drawing for piano/keyboard, the
/// instrument's emoji for everything else. [fallback] is used when no
/// instrument is known.
Widget instrumentIcon(String? instrument,
    {double size = 24, String fallback = '🎵'}) {
  if (isPianoInstrument(instrument)) return PianoIcon(size: size);
  final e = instrument == null || instrumentEmoji(instrument) == '🎵'
      ? fallback
      : instrumentEmoji(instrument);
  return Text(e, style: TextStyle(fontSize: size * 0.85));
}

/// Text in which any piano emoji is drawn as the piano image instead.
class PianoText extends StatelessWidget {
  const PianoText(this.text, {super.key, this.style, this.maxLines, this.overflow});
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    if (!text.contains('🎹')) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }
    final base = DefaultTextStyle.of(context).style.merge(style);
    final size = (base.fontSize ?? 14) * 1.3;
    final parts = text.split('🎹');
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i]));
      if (i < parts.length - 1) {
        spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: PianoIcon(size: size)));
      }
    }
    return Text.rich(TextSpan(children: spans),
        style: style, maxLines: maxLines, overflow: overflow);
  }
}
