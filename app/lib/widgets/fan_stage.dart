import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';
import '../state/app_state.dart';
import '../state/wardrobe.dart';
import '../theme/jamjot_theme.dart';
import 'dressed_avatar.dart';
import 'letter_avatar.dart' show artAsset, studentAvatarKey;

/// Every new student opens their first show to a small friendly crowd.
/// (Display-side seed for now; becomes a server-side ledger grant at the
/// venue-world backend release.)
const starterFans = 10;

/// The venue ladder: parodies of famous stages, smallest to biggest, ordered
/// by the real venues' capacities. Fans only ever grow, so a venue is never
/// lost. (Backdrops are placeholder scenes — Erika's art swaps in later.)
class Venue {
  const Venue(this.minFans, this.name, this.scene, this.top, this.bottom,
      {required this.accent,
      required this.motif,
      required this.realStage,
      required this.exclusives,
      this.lore = ''});

  /// A kid-facing line of personality for the Tour page.
  final String lore;
  final int minFans;
  final String name;
  final String scene; // emoji marker
  final Color top;
  final Color bottom;

  /// This venue's single accent color (kids-only theme touch, JJ-013).
  final Color accent;

  /// Small header motif (kids-only theme touch).
  final String motif;

  /// The real stage behind the parody, for the Tour page.
  final String realStage;

  /// Market-exclusive accessory ids unlocked by playing this venue.
  final List<String> exclusives;
}

const venues = [
  Venue(0, 'The Village Vineguard', '🕯️', Color(0xFF55403A), Color(0xFF3A2E28),
      accent: Color(0xFFE8A23D),
      motif: '🕯️',
      realStage:
          'After the Village Vanguard in New York — a basement jazz club open '
          'since 1935 that seats only about 120, where legends like John '
          'Coltrane recorded live albums.',
      lore:
          'Where every band begins: a candle-lit cellar, ten loyal fans, and butterflies before the first song.',
      exclusives: ['beret', 'candle']),
  Venue(30, 'The Blue Note Berry', '🎷', Color(0xFF3A4A7A), Color(0xFF232B4A),
      accent: Color(0xFF4A5FAE),
      motif: '🎷',
      realStage:
          'After the Blue Note in Greenwich Village — around 200 seats, a '
          'nightly stop for the world\'s top jazz players since 1981.',
      lore:
          'A smoky-blue jazz room where the sax never sleeps and the cool kids snap instead of clap.',
      exclusives: ['blue_shades', 'bass_pin']),
  Venue(80, 'The Raspberry Roxy', '💡', Color(0xFF4B4668), Color(0xFF2A2546),
      accent: Color(0xFFE57BA0),
      motif: '💡',
      realStage:
          'After The Roxy on the Sunset Strip in Los Angeles — a 500-person '
          'club where new acts have launched since 1973; Bob Marley recorded '
          'a famous live set there.',
      lore:
          'Velvet walls, a glowing marquee — and tonight, your name is on it.',
      exclusives: ['leather_jacket', 'nameplate']),
  Venue(180, 'The Jampollo Theater', '🌟', Color(0xFF4B4668), Color(0xFF2E2A4A),
      accent: Color(0xFFFFD66B),
      motif: '🌟',
      realStage:
          'After the Apollo Theater in Harlem — about 1,500 seats, home of '
          'Amateur Night since 1934, where Ella Fitzgerald and James Brown '
          'broke through.',
      lore:
          'The legendary stage where stars are born. Bring your very best.',
      exclusives: ['bow_tie', 'golden_mic']),
  Venue(350, 'Jarnegie Hall', '🏛️', Color(0xFFE4ECF9), Color(0xFFBDD1F0),
      accent: Color(0xFFF2B747),
      motif: '🏛️',
      realStage:
          'After Carnegie Hall in New York — roughly 2,800 seats, opened in '
          '1891 with Tchaikovsky conducting. How do you get there? Practice!',
      lore:
          'How do you get here? Practice, practice, practice.',
      exclusives: ['white_gloves', 'baton']),
  Venue(600, 'Red Rocks Jamphitheatre', '⛰️', Color(0xFFFFD9A0), Color(0xFFF6A46B),
      accent: Color(0xFFC96F4A),
      motif: '⛰️',
      realStage:
          'After Red Rocks Amphitheatre near Denver — about 9,500 seats '
          'carved between two enormous red sandstone slabs, under open sky.',
      lore:
          'An open-air amphitheater carved into berry-red cliffs, under a sky full of stars.',
      exclusives: ['bandana', 'hiking_boots']),
  Venue(1000, 'The Hollyberry Bowl', '🎆', Color(0xFF3A4A7A), Color(0xFF1B244A),
      accent: Color(0xFF9AA9DC),
      motif: '🎆',
      realStage:
          'After the Hollywood Bowl in Los Angeles — about 17,500 seats '
          'under its iconic white shell, open since 1922.',
      lore:
          'Fireworks over the bandshell — the whole city came to listen.',
      exclusives: ['star_shades', 'sparkler']),
  Venue(1500, 'Madison Jar Garden', '🏟️', Color(0xFF4B4668), Color(0xFF2A2546),
      accent: Color(0xFF9B7ED9),
      motif: '📺',
      realStage:
          'After Madison Square Garden — the 20,000-seat arena nicknamed '
          '"the world\'s most famous arena."',
      lore:
          'The world\'s most famous arena, packed to the rafters and chanting your name.',
      exclusives: ['champ_jacket', 'wristband']),
  Venue(2500, 'Jamberly Stadium', '🌈', Color(0xFFE3EDF7), Color(0xFFBBDCF1),
      accent: Color(0xFF7CB56B),
      motif: '🌈',
      realStage:
          'After Wembley Stadium in London — 90,000 seats under its giant '
          'arch, scene of Live Aid in 1985.',
      lore:
          'A rainbow over fifty thousand cheering fans. Can you hear them?',
      exclusives: ['stadium_scarf', 'crown_headset']),
  Venue(4000, 'JamJot Stadium', '🫙', Color(0xFFFFECC2), Color(0xFFFFDE8A),
      accent: Color(0xFFFFBE2E),
      motif: '🫙',
      realStage:
          'The invented finale — JamJot\'s very own mega-stadium, bigger '
          'than any real one. This stage is yours.',
      lore:
          'The biggest stage there is — and look at the name: it\'s practically yours.',
      exclusives: ['golden_cape', 'jar_crown']),
];

(int, Venue) venueFor(int fans) {
  var level = 0;
  for (var i = 0; i < venues.length; i++) {
    if (fans >= venues[i].minFans) level = i;
  }
  return (level + 1, venues[level]);
}

/// Lifetime fans as shown to the kid: ledger total plus the small opening
/// crowd every student starts with.
int displayedFans(WidgetRef ref, String studentId) =>
    starterFans + (ref.watch(fanTotalProvider(studentId)).valueOrNull ?? 0);

/// The crowd, drawn as a silhouette audience (founder reference style) in
/// sensible ratio to the stage: a thin sliver of people at 10 fans, a packed
/// house as the venue fills toward its next target.
class CrowdStrip extends StatelessWidget {
  const CrowdStrip(
      {super.key,
      required this.fans,
      this.height = 48,
      this.dark = false,
      this.full = 300});
  final int fans;
  final double height;

  /// Black silhouettes for bright venues, colored for dark stages.
  final bool dark;

  /// How many fans fill the frame completely.
  final int full;

  @override
  Widget build(BuildContext context) {
    final fraction = (fans / full).clamp(0.12, 1.0).toDouble();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          widthFactor: fraction,
          child: ClipRect(
            // Draw the crowd at its true proportions (people ~the height of
            // the strip) and tile it sideways as the crowd grows — never
            // stretched or cropped lengthwise.
            child: Container(
              height: height,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(dark
                      ? 'assets/art/crowd_black.png'
                      : 'assets/art/crowd_color.png'),
                  repeat: ImageRepeat.repeatX,
                  alignment: Alignment.bottomCenter,
                  scale: (dark ? 445 : 402) / height,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fans earned since Monday.
final weeklyFansProvider =
    FutureProvider.autoDispose.family<int, String>((ref, studentId) async {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  final rows = await JamJotBackend.client
      .from('fan_ledger')
      .select('amount, created_at, sessions(started_at)')
      .eq('student_id', studentId);
  var total = 0;
  for (final r in rows) {
    final a = (r['amount'] as num).toInt();
    final at = DateTime.parse(
            (r['sessions'] as Map?)?['started_at'] as String? ??
                r['created_at'] as String)
        .toLocal();
    if (!at.isBefore(monday) && !at.isAfter(now)) total += a;
  }
  return total;
});

/// The crowd at the student's current venue: lifetime fans, this week's
/// haul, and how far to the next stage.
class FanStage extends ConsumerWidget {
  const FanStage({super.key, required this.studentId, this.compact = false});
  final String studentId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final fans = displayedFans(ref, studentId);
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
                    style:
                        text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                Text(
                  '🕶️ $fans fan${fans == 1 ? '' : 's'} ever • +$weekly this week${possible > 0 ? ' (of ~$possible possible)' : ''}',
                  style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ]),
        if (!compact) ...[
          const SizedBox(height: 8),
          // The crowd, in true scale to the stage.
          if (crowdCount == 0)
            Text('The seats are waiting for your first fans! 🎵',
                style: text.bodySmall)
          else
            CrowdStrip(
                fans: fans,
                height: 34,
                full: next?.minFans ?? venue.minFans + 500),
        ],
        if (next != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ((fans - venue.minFans) / (next.minFans - venue.minFans))
                  .clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.6),
              color: venue.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${next.minFans - fans} more fans to ${next.name} ${next.scene}',
            style: text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ] else
          Text('Top of the tour — JamJot Stadium is yours! 🫙',
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
          child: artAsset('venue_$venueIndex', fit: BoxFit.cover),
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
    final fans = displayedFans(ref, studentId);
    final (_, venue) = venueFor(fans);
    final venueIndex = venues.indexOf(venue);
    final crowdCount = fans <= 0 ? 0 : (fans / 4).ceil().clamp(1, 36);
    final active = ref.watch(activeStudentProvider);
    final wornKey = studentAvatarKey(active?['avatar_key'] as String?);
    final outfit = ref.watch(wardrobeProvider(studentId)).outfitFor(wornKey);
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
      // A wash that keeps the content readable, fading as it reaches the
      // stage so the venue stays present without stealing focus.
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.55, 1.0],
            colors: [
              Color(0xE8FAF6EE), // solid enough for text up top
              Color(0xC9FAF6EE),
              Color(0x7DFAF6EE), // the stage shows through down here
            ],
          ),
        ),
      ),
      // The kid's own avatar and their crowd sit crisp ABOVE the wash.
      Positioned(
        bottom: 34,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: DressedAvatar(
                avatarKey: wornKey, outfit: outfit, size: 64),
          ),
        ),
      ),
      // Their crowd, gathered at the stage in true scale.
      if (crowdCount > 0)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: CrowdStrip(
                fans: fans,
                height: 52,
                full: venues[(venues.indexOf(venue) + 1)
                        .clamp(0, venues.length - 1)]
                    .minFans),
          ),
        ),
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
    final fans = displayedFans(ref, studentId);
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
        Text(venue.motif, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Level $level — ${venue.name}',
                  style:
                      text.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(
                next == null
                    ? '🕶️ $fans fans — top of the tour!'
                    : '🕶️ $fans fan${fans == 1 ? '' : 's'} • ${next.minFans - fans} more to ${next.name} ${next.scene}',
                style: text.labelSmall?.copyWith(color: JamJotColors.inkSoft),
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
                    color: venue.accent,
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
