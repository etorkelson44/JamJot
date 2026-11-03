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
  });

  final String title;
  final String? subtitle;
  final String? emoji;
  final Color? tint;
  final VoidCallback? onTap;
  final Widget? trailing;

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
              if (emoji != null) ...[
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint ?? JamJotColors.neutral,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(emoji!, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
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
