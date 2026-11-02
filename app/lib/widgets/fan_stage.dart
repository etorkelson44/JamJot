import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';
import '../state/app_state.dart';
import '../theme/jamjot_theme.dart';
import 'letter_avatar.dart' show artAsset;

/// The venue ladder: more fans → bigger stage. (Placeholder scenes — each
/// venue becomes a real illustrated backdrop later.)
class Venue {
  const Venue(this.minFans, this.name, this.scene, this.top, this.bottom);
  final int minFans;
  final String name;
  final String scene;
  final Color top;
  final Color bottom;
}

const venues = [
  Venue(0, 'Living Room', '🛋️', Color(0xFFFFF3DC), Color(0xFFFFE3B3)),
  Venue(25, 'Backyard Porch', '🌳', Color(0xFFE8F5D8), Color(0xFFCDE8B5)),
  Venue(60, 'Street Corner', '🚏', Color(0xFFE3EDF7), Color(0xFFC7DBEE)),
  Venue(120, 'Park Bandstand', '⛲', Color(0xFFDFF2EC), Color(0xFFBCE3D6)),
  Venue(220, 'School Gym', '🏫', Color(0xFFF3E6F7), Color(0xFFE2C8EC)),
  Venue(350, "Farmers' Market Stage", '🧺', Color(0xFFFCEBDD), Color(0xFFF6D1B3)),
  Venue(550, 'Town Theater', '🎭', Color(0xFFEDE4F9), Color(0xFFD3BFF0)),
  Venue(800, 'Concert Hall', '🎻', Color(0xFFE4ECF9), Color(0xFFBDD1F0)),
  Venue(1200, 'Big Arena', '🎤', Color(0xFFFBE3E8), Color(0xFFF3BCC9)),
  Venue(1800, 'JamJot Stadium', '🏟️', Color(0xFFFFF0C9), Color(0xFFFFDE8A)),
];

(int, Venue) venueFor(int fans) {
  var level = 0;
  for (var i = 0; i < venues.length; i++) {
    if (fans >= venues[i].minFans) level = i;
  }
  return (level + 1, venues[level]);
}

/// Fans earned since Monday.
final weeklyFansProvider =
    FutureProvider.autoDispose.family<int, String>((ref, studentId) async {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  final rows = await JamJotBackend.client
      .from('fan_ledger')
      .select('amount')
      .eq('student_id', studentId)
      .gte('created_at', monday.toUtc().toIso8601String());
  var total = 0;
  for (final r in rows) {
    final a = (r['amount'] as num).toInt();
    if (a > 0) total += a;
  }
  return total;
});

const _fanFaces = ['🙂', '😄', '🤩', '😊', '😎', '🥳', '😁', '🫨'];

/// The crowd at the student's current venue: lifetime fans, this week's
/// haul, and how far to the next stage.
class FanStage extends ConsumerWidget {
  const FanStage({super.key, required this.studentId, this.compact = false});
  final String studentId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final fans = ref.watch(fanTotalProvider(studentId)).valueOrNull ?? 0;
    final weekly = ref.watch(weeklyFansProvider(studentId)).valueOrNull ?? 0;
    final lesson = ref.watch(currentLessonProvider(studentId)).valueOrNull;
    final songs = (lesson?['assignments'] as List? ?? []).length;
    // Roughly what a full week of finishing every song could bring.
    final possible = songs == 0 ? 0 : songs * 5 * 7;
    final (level, venue) = venueFor(fans);
    final next = level < venues.length ? venues[level] : null;

    final crowdCount = fans <= 0 ? 0 : (fans / 4).ceil().clamp(1, 48);
    final venueIndex = venues.indexOf(venue);

    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(venue.scene, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Level $level — ${venue.name}',
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    '🕶️ $fans fan${fans == 1 ? '' : 's'} ever • +$weekly this week${possible > 0 ? ' (of ~$possible possible)' : ''}',
                    style: text.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ]),
          if (!compact) ...[
            const SizedBox(height: 8),
            // The crowd (one little face per few fans).
            if (crowdCount == 0)
              Text('The seats are waiting for your first fans! 🎵',
                  style: text.bodySmall)
            else
              Wrap(
                spacing: 1,
                runSpacing: 1,
                children: [
                  for (var i = 0; i < crowdCount; i++)
                    artAsset('fan_${i % 4}',
                        width: 19, height: 19),
                ],
              ),
          ],
          if (next != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ((fans - venue.minFans) /
                        (next.minFans - venue.minFans))
                    .clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.6),
                color: JamJotColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${next.minFans - fans} more fans to the ${next.name} ${next.scene}',
              style: text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ] else
            Text('Top of the ladder — the stadium is yours! 🏟️',
                style: text.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
        ],
      );

    // The venue backdrop sits behind everything, with a soft wash so the
    // words stay readable.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JamJotColors.ink, width: 2),
      ),
      child: Stack(children: [
        Positioned.fill(
          child: artAsset('venue_$venueIndex',
              fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: Container(color: Colors.white.withValues(alpha: 0.55)),
        ),
        Padding(padding: const EdgeInsets.all(14), child: content),
      ]),
    );
  }
}


/// The kid's current venue as a soft full-page backdrop: the stage scene
/// with their earned crowd standing in it, washed back so the page on top
/// stays easy to read.
class VenueBackdrop extends ConsumerWidget {
  const VenueBackdrop(
      {super.key, required this.studentId, required this.child});
  final String studentId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fans = ref.watch(fanTotalProvider(studentId)).valueOrNull ?? 0;
    final (_, venue) = venueFor(fans);
    final venueIndex = venues.indexOf(venue);
    final crowdCount = fans <= 0 ? 0 : (fans / 4).ceil().clamp(1, 36);
    return Stack(fit: StackFit.expand, children: [
      // The stage scene, anchored to the bottom of the page.
      Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: 300,
          width: double.infinity,
          child: artAsset('venue_$venueIndex',
              fit: BoxFit.cover, alignment: Alignment.bottomCenter),
        ),
      ),
      // Their crowd, gathered at the stage.
      if (crowdCount > 0)
        Positioned(
          left: 10,
          right: 10,
          bottom: 8,
          child: IgnorePointer(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 1,
              children: [
                for (var i = 0; i < crowdCount; i++)
                  artAsset('fan_${i % 4}',
                      width: 17, height: 17),
              ],
            ),
          ),
        ),
      // The wash that keeps everything readable.
      Container(color: const Color(0xFFFAF6EE).withValues(alpha: 0.82)),
      child,
    ]);
  }
}


/// The compact venue indicator that rides on top of the backdrop: which
/// stage this is, the fan count, and how far to the next venue.
class FanIndicator extends ConsumerWidget {
  const FanIndicator({super.key, required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final fans = ref.watch(fanTotalProvider(studentId)).valueOrNull ?? 0;
    final (level, venue) = venueFor(fans);
    final next = level < venues.length ? venues[level] : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JamJotColors.ink, width: 2),
      ),
      child: Row(children: [
        Text(venue.scene, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Level $level — ${venue.name}',
                  style: text.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(
                next == null
                    ? '🕶️ $fans fans — top of the ladder!'
                    : '🕶️ $fans fan${fans == 1 ? '' : 's'} • ${next.minFans - fans} more to the ${next.name} ${next.scene}',
                style: text.labelSmall
                    ?.copyWith(color: JamJotColors.inkSoft),
              ),
              if (next != null) ...[
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ((fans - venue.minFans) /
                            (next.minFans - venue.minFans))
                        .clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: JamJotColors.blueberryTint,
                    color: JamJotColors.ink,
                  ),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}
