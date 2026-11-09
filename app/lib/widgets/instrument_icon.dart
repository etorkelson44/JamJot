import 'package:flutter/material.dart';

import '../models/instruments.dart';

/// One place that decides how an instrument is drawn (JJ-036-C).
///
/// Every instrument shows its photo icon from assets/instruments/ on a
/// white rounded tile (some photos have white, not transparent,
/// backgrounds). Saved values are matched by [resolveInstrument]; anything
/// not on the list gets the music-notes "Other" picture.
class InstrumentIcon extends StatelessWidget {
  const InstrumentIcon(this.instrument, {super.key, this.size = 24});

  /// The saved instrument text (any spelling), or null.
  final String? instrument;
  final double size;

  @override
  Widget build(BuildContext context) {
    final entry = resolveInstrument(instrument);
    return Semantics(
      image: true,
      label: instrument ?? 'Music',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.06),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.24),
          border: Border.all(color: const Color(0x1F000000)),
        ),
        child: Image.asset(
          entry.asset,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          errorBuilder: (_, __, ___) => FittedBox(
              child: Text('🎵', style: TextStyle(fontSize: size * 0.7))),
        ),
      ),
    );
  }
}

/// An icon for an instrument. [fallback] is kept for older callers and is
/// no longer used: unknown instruments show the "Other" picture.
Widget instrumentIcon(String? instrument,
        {double size = 24, String fallback = '🎵'}) =>
    InstrumentIcon(instrument, size: size);

/// The instrument's icon followed by its name, exactly as saved.
class InstrumentLabel extends StatelessWidget {
  const InstrumentLabel(this.instrument,
      {super.key, this.style, this.iconSize = 22});
  final String instrument;
  final TextStyle? style;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InstrumentIcon(instrument, size: iconSize),
          const SizedBox(width: 6),
          Flexible(
              child: Text(instrument,
                  style: style, overflow: TextOverflow.ellipsis)),
        ],
      );
}

/// Several instruments, each with its icon (wraps onto new lines).
class InstrumentList extends StatelessWidget {
  const InstrumentList(this.instruments,
      {super.key, this.style, this.iconSize = 22, this.empty = ''});
  final List instruments;
  final TextStyle? style;
  final double iconSize;

  /// Text shown when there are no instruments.
  final String empty;

  @override
  Widget build(BuildContext context) {
    final names = instruments.whereType<String>().toList();
    if (names.isEmpty) {
      return empty.isEmpty ? const SizedBox.shrink() : Text(empty, style: style);
    }
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final n in names)
          InstrumentLabel(n, style: style, iconSize: iconSize),
      ],
    );
  }
}

/// The founder's piano drawing, sized like an icon. Used inline by
/// [PianoText] for "instrument play" assignment labels.
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
