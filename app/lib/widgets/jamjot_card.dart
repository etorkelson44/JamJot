import 'package:flutter/material.dart';

import '../theme/jamjot_theme.dart';

/// The signature JamJot card: white, 2px ink border, 20px corners.
class JamJotCard extends StatelessWidget {
  const JamJotCard({
    super.key,
    required this.title,
    this.subtitle,
    this.emoji,
    this.tint,
    this.onTap,
    this.trailing,
    this.leading,
    this.titleWidget,
    this.extra,
  });

  /// Shown instead of the [title] text (e.g. instruments with icons).
  final Widget? titleWidget;

  /// Shown between the title and the subtitle.
  final Widget? extra;

  /// Custom leading widget shown in the tile slot instead of [emoji].

  final String title;
  final String? subtitle;
  final String? emoji;
  final Color? tint;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
        side: JamJotShape.border,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (leading != null || emoji != null) ...[
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint ?? JamJotColors.neutral,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: leading ?? Text(emoji!, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget ??
                        Text(title,
                            style: text.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                    if (extra != null) ...[
                      const SizedBox(height: 4),
                      extra!,
                      const SizedBox(height: 2),
                    ],
                    if (subtitle != null)
                      Text(subtitle!,
                          style: text.bodySmall
                              ?.copyWith(color: JamJotColors.inkSoft)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
