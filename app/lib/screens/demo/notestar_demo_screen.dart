import 'package:flutter/material.dart';

import '../../services/sound_effects.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/alien_fans.dart';
import '../../widgets/star_currency.dart';

/// Preview-only page (notestar-look branch) so the founder can watch the
/// star currency and the alien fans without earning anything. Not shipped.
class NoteStarDemoScreen extends StatefulWidget {
  const NoteStarDemoScreen({super.key});
  @override
  State<NoteStarDemoScreen> createState() => _NoteStarDemoScreenState();
}

class _NoteStarDemoScreenState extends State<NoteStarDemoScreen> {
  int _run = 0, _count = 42, _earn = 8;
  bool _flying = false;
  final _corner = GlobalKey();

  void _play(int earn) {
    final tl = StarTimeline(start: _count, earn: earn);
    playCoinPings(tl.tickDelays);
    setState(() {
      _earn = earn;
      _run++;
      _flying = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Rect? rect;
    final box = _corner.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      rect = box.localToGlobal(Offset.zero) & box.size;
    }
    return Scaffold(
      backgroundColor: JamJotColors.marigold,
      body: Stack(children: [
        SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Row(children: [
              Expanded(
                  child: Text('NoteStar preview',
                      style: text.headlineSmall
                          ?.copyWith(fontFamily: JamJotType.display))),
              Opacity(
                  opacity: _flying ? 0 : 1,
                  child: StarStill(key: _corner, balance: _count, width: 58)),
            ]),
            const SizedBox(height: 16),
            Text('Stars', style: text.titleLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton(
                  onPressed: () => _play(8), child: const Text('Earn 8 stars')),
              FilledButton(
                  onPressed: () => _play(25),
                  child: const Text('Earn 25 stars')),
            ]),
            const SizedBox(height: 28),
            Text('Your alien fans', style: text.titleLarge),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: () => playSound('cheer'),
                child: const Text('Play the cheer')),
            const SizedBox(height: 12),
            const Center(child: AlienCrowd(width: 340)),
          ]),
        ),
        if (_flying)
          Positioned.fill(
            child: IgnorePointer(
              child: StarFlight(
                key: ValueKey(_run),
                startCount: _count,
                earned: _earn,
                cornerCenter: rect?.center,
                cornerWidth: rect?.width ?? 58,
                onDone: () => setState(() {
                  _count += _earn;
                  _flying = false;
                }),
              ),
            ),
          ),
      ]),
    );
  }
}
