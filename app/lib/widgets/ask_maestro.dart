import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/jamjot_theme.dart';
import 'conducting_maestro.dart';

/// Maestro Marmalade — JamJot's helper (not a market avatar). A small tab
/// rides the edge of main pages; tapping it pops Maestro out with a chat of
/// preset questions and answers. (Support tickets arrive here later.)
const _maestroQA = <(String, String)>[
  (
    'How do I earn coins? 🪙',
    'Every minute of real practice sound earns coins, and finishing a song '
        'earns a bonus! Spend them at the Market on new band members and '
        'closet pieces.'
  ),
  (
    'What are fans and venues? 🕶️',
    'Fans come to hear you play — you earn them by finishing songs and '
        'meeting your weekly goals. The more fans, the bigger your stage: '
        'from The Jam Cellar all the way to JamJot Stadium. Fans never '
        'leave, so your venue is yours to keep!'
  ),
  (
    'How does recording work? 🎙️',
    'Press record on the practice page and just play — JamJot listens for '
        'real music sound and counts it. Each song needs about a minute of '
        'sound to count as finished. Your recordings are saved so you and '
        'your grown-ups can listen back.'
  ),
  (
    'What is My Ensemble? 🎸',
    'Your backstage! On Stage shows your whole band at your current venue — '
        'tap a member to put them in the spotlight. The Dressing Room holds '
        'every accessory you own, and the Tour shows every stage on your '
        'journey.'
  ),
  (
    'How do I get new avatars and outfits? 🧺',
    'Visit the Market! Band members cost coins and bring their own '
        'accessories with them. Some special pieces only unlock when you '
        'play a certain venue — check the Tour to see what\'s coming.'
  ),
  (
    'A practice looks wrong — can it be fixed? 🛠️',
    'Yes — ask a grown-up! Caregivers and teachers can fix minutes, remove '
        'a practice, or delete a recording from the practice history page. '
        'Your recordings and honest minutes stay safe.'
  ),
  (
    'Can we save our data somewhere? 💾',
    'A grown-up can download everything — practice history, lessons and all '
        'the recordings — from their Settings page. It arrives as one tidy '
        'folder that opens anywhere, no JamJot needed.'
  ),
];

/// The edge tab that summons Maestro.
class AskMaestroTab extends StatelessWidget {
  const AskMaestroTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: MediaQuery.of(context).size.height * 0.30,
      child: GestureDetector(
        onTap: () => showMaestroHelp(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 4, 10),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF2CF),
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
            border: Border(
              top: BorderSide(color: JamJotColors.ink, width: 2),
              left: BorderSide(color: JamJotColors.ink, width: 2),
              bottom: BorderSide(color: JamJotColors.ink, width: 2),
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/mascot/maestro_tux.png', width: 34),
            const SizedBox(height: 2),
            const Text('?',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: JamJotColors.ink)),
          ]),
        ),
      ),
    );
  }
}

Future<void> showMaestroHelp(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => const _MaestroSheet(),
  );
}

class _MaestroSheet extends StatefulWidget {
  const _MaestroSheet();

  @override
  State<_MaestroSheet> createState() => _MaestroSheetState();
}

class _MaestroSheetState extends State<_MaestroSheet> {
  int? _openQuestion;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                  color: JamJotColors.inkSoft,
                  borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 10),
          // Maestro conducts his welcome with his pencil baton.
          const Center(child: ConductingMaestro(height: 130)),
          const SizedBox(height: 8),
          Center(
            child: Text('Ask Maestro Marmalade!',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
          // His introduction, chat-style.
          _bubble(
              context,
              '🎼 Well hello there! I\'m Maestro Marmalade — JamJot\'s '
              'conductor, helper, and number-one fan. Tap a question and '
              'I\'ll explain!'),
          const SizedBox(height: 12),
          for (var i = 0; i < _maestroQA.length; i++) ...[
            _questionChip(context, i),
            if (_openQuestion == i) ...[
              const SizedBox(height: 8),
              _bubble(context, _maestroQA[i].$2),
            ],
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Text(
            'Something else on your mind? A way to send Maestro a note is '
            'coming soon — for now, tell your grown-up or teacher!',
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(color: JamJotColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, String message) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Image.asset('assets/mascot/maestro_tux.png', width: 30),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF2CF),
            borderRadius: BorderRadius.circular(16).copyWith(
                topLeft: const Radius.circular(4)),
            border: Border.all(color: JamJotColors.ink, width: 2),
          ),
          child: Text(message),
        ),
      ),
    ]);
  }

  Widget _questionChip(BuildContext context, int i) {
    final selected = _openQuestion == i;
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _openQuestion = selected ? null : i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? JamJotColors.blueberryTint : Colors.white,
            borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: const Radius.circular(4)),
            border: Border.all(color: JamJotColors.ink, width: 2),
          ),
          child: Text(_maestroQA[i].$1,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

/// Maestro searching with his magnifying glass — the animated version of the
/// empty-calendar moment (art: founder's tuxedo magnifier pose).
class MaestroSearching extends StatefulWidget {
  const MaestroSearching({super.key, this.size = 150});
  final double size;

  @override
  State<MaestroSearching> createState() => _MaestroSearchingState();
}

class _MaestroSearchingState extends State<MaestroSearching>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        // He leans left and right, scanning every measure.
        final lean = math.sin(t * 2 * math.pi) * 0.09;
        final shift = math.sin(t * 2 * math.pi) * widget.size * 0.08;
        return Transform.translate(
          offset: Offset(shift, 0),
          child: Transform.rotate(
              angle: lean, alignment: Alignment.bottomCenter, child: child),
        );
      },
      child: Image.asset('assets/mascot/maestro_search.png',
          height: widget.size),
    );
  }
}

/// The Tisdale Applications imprint: the maker's mark, kept quiet — visible
/// if you look, invisible if you don't.
class TisdaleImprint extends StatelessWidget {
  const TisdaleImprint({super.key, this.height = 34, this.opacity = 0.14});
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Opacity(
        opacity: opacity,
        child: Image.asset('assets/art/brand_tisdale.png', height: height),
      ),
    );
  }
}
