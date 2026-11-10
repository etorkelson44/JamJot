import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/jamjot_theme.dart';

/// "Berries and Cream! Looks like we're jammed up." — the one screen JamJot
/// shows whenever a page goes wrong, instead of a blank or error page.
///
/// Used four ways: the `/jammed` page for unknown addresses, the stand-in for
/// any screen that crashes while drawing (see `ErrorWidget.builder` in
/// main.dart), the whole app when it can't start, and the plain-HTML twin in
/// web/index.html for when the app can't load at all.
///
/// It adapts to the room it's given — a full page, a compact card (a broken
/// list item), or just Maestro (a tiny slot) — and deliberately leans on
/// nothing that could itself be broken: no providers, router or MediaQuery.
class JammedUp extends StatelessWidget {
  const JammedUp({super.key, this.onRetry, this.onHome});

  /// Reloads and tries again. Hidden when null (e.g. an unknown address,
  /// where trying the same thing again can't help).
  final VoidCallback? onRetry;

  /// Heads back to the start. Hidden when null.
  final VoidCallback? onHome;

  static const String message =
      'Berries and Cream! Looks like we\u2019re jammed up.';

  /// Directions for moving forward — one short directive for kids and grown-ups
  /// alike (workshopped with the founder, 2026-11-06).
  /// When there is a Try again button:
  static const String directions =
      'Tap Try again. Still stuck? Tap Back to start.';

  /// When there is no Try again button (an address that doesn't exist):
  static const String directionsLost =
      'That page has wandered off. Tap Back to start.';

  static const String artAsset = 'assets/mascot/maestro_jammed.png';

  static final ButtonStyle _primary = FilledButton.styleFrom(
    backgroundColor: JamStand.amber,
    foregroundColor: JamStand.ink,
    minimumSize: const Size(168, 52),
    shape: const StadiumBorder(),
    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
  );

  static final ButtonStyle _secondary = OutlinedButton.styleFrom(
    foregroundColor: JamStand.ink,
    minimumSize: const Size(168, 52),
    shape: const StadiumBorder(),
    side: const BorderSide(color: JamStand.crate, width: 2),
    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
  );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        if (!w.isFinite || w < 200 || (h.isFinite && h < 130)) {
          return _tiny(w, h);
        }
        if (h.isFinite && h >= 420 && w >= 300) return _full(context, h);
        return _compact(context);
      }),
    );
  }

  Widget _art(double height) => Image.asset(
        artAsset,
        height: height,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        // If even the picture is missing, leave a quiet gap, never an error.
        errorBuilder: (_, __, ___) => SizedBox(height: height),
      );

  /// Just Maestro, for slots too small for words.
  Widget _tiny(double w, double h) {
    final side = [48.0, if (w.isFinite) w, if (h.isFinite) h].reduce(math.min);
    return Semantics(
      label: message,
      child: Center(child: _art(side)),
    );
  }

  /// A small card: Maestro beside the message (a broken list item, say).
  Widget _compact(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: JamStand.paper,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Semantics(
          container: true,
          label: message,
          child: Row(children: [
            _art(64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: (text.titleSmall ?? const TextStyle(fontSize: 14))
                        .copyWith(
                      color: JamStand.ink,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (onRetry != null)
                    TextButton(onPressed: onRetry, child: const Text('Try again')),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// The full page.
  Widget _full(BuildContext context, double height) {
    final text = Theme.of(context).textTheme;
    final title = (text.headlineSmall ?? const TextStyle(fontSize: 24)).copyWith(
      color: JamStand.ink,
      fontWeight: FontWeight.w800,
      height: 1.2,
      decoration: TextDecoration.none,
    );
    final body = (text.bodyLarge ?? const TextStyle(fontSize: 16)).copyWith(
      color: JamStand.inkSoft,
      height: 1.4,
      decoration: TextDecoration.none,
    );
    final buttons = <Widget>[
      if (onRetry != null)
        FilledButton(
            style: _primary, onPressed: onRetry, child: const Text('Try again')),
      if (onHome != null)
        onRetry != null
            ? OutlinedButton(
                style: _secondary,
                onPressed: onHome,
                child: const Text('Back to start'))
            : FilledButton(
                style: _primary,
                onPressed: onHome,
                child: const Text('Back to start')),
    ];
    return Material(
      color: JamStand.paper,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Semantics(
              container: true,
              label: 'Maestro Marmalade looks worried. $message',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _art((height * 0.38).clamp(140.0, 340.0)),
                  const SizedBox(height: 24),
                  Text(message, textAlign: TextAlign.center, style: title),
                  const SizedBox(height: 12),
                  Text(onRetry != null ? directions : directionsLost,
                      textAlign: TextAlign.center, style: body),
                  if (buttons.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: buttons,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
