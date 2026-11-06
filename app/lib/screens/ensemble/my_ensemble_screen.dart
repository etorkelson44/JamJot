import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../state/wardrobe.dart';
import '../../services/sound_effects.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/ask_maestro.dart' show TisdaleImprint;
import '../../widgets/dressed_avatar.dart';
import '../../widgets/fan_stage.dart';
import '../../widgets/letter_avatar.dart' show artAsset;
import '../../widgets/maestro_tour_bus.dart';
import '../market/market_screen.dart' show purchasesProvider;
import '../../models/market_avatars.dart' show musicalAvatars;

/// Display names for band members (falls back to the musical-avatar cast).
String _avatarName(String key) {
  if (key == 'sonatina') return 'Sonatina Sprout';
  final cast = musicalAvatars[key];
  if (cast != null) return cast.name;
  return key[0].toUpperCase() + key.substring(1);
}

/// My Ensemble — the kid's backstage world (JJ-014):
/// On Stage · Dressing Room · Tour.
class MyEnsembleScreen extends ConsumerStatefulWidget {
  const MyEnsembleScreen({super.key});

  @override
  ConsumerState<MyEnsembleScreen> createState() => _MyEnsembleScreenState();
}

class _MyEnsembleScreenState extends ConsumerState<MyEnsembleScreen>
    with TickerProviderStateMixin {
  int _cheerSeq = 0;
  String? _ghost; // locked item being "imagined" in the mirror
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeStudentProvider);
    if (active == null) {
      return const Scaffold(
        body: Center(
            child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
              'My Ensemble is each musician\'s own backstage —\npick a kid profile to visit theirs! 🎸',
              textAlign: TextAlign.center),
        )),
      );
    }
    final sid = active['id'] as String;
    final wornKey = (active['avatar_key'] as String?) ?? 'jalapeno';
    final purchases = ref.watch(purchasesProvider(sid)).valueOrNull ?? [];
    // Every kid's band starts with the three freebies (Tour 2.0 interim,
    // founder-directed 2026-11-05; third member per JJ-021-C): Señor
    // Jalapresto, Ms. Straw-ccato and Keywi.
    final owned = <String>['jalapeno', 'strawberry', 'kiwi'];
    for (final p in purchases) {
      final item = p['market_items'] as Map<String, dynamic>?;
      final key = item?['asset_key'] as String?;
      if (item?['kind'] == 'avatar' && key != null && !owned.contains(key)) {
        owned.add(key);
      }
    }
    final fans = displayedFans(ref, sid);
    final coins = ref.watch(berryBalanceProvider(sid)).valueOrNull ?? 0;
    final (level, venue) = venueFor(fans);
    final wardrobe = ref.watch(wardrobeProvider(sid));
    // Owned avatars always carry their bundled accessories.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(wardrobeProvider(sid).notifier).ensureBundles(owned);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(venue.motif, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text('My Ensemble'),
        ]),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'On Stage'),
          Tab(text: 'Dressing Room'),
          Tab(text: 'Tour'),
        ]),
      ),
      body: TabBarView(controller: _tabs, children: [
        _onStage(context, sid, wornKey, owned, wardrobe, venue, level,
            fans, coins),
        _dressingRoom(context, sid, wornKey, owned, wardrobe, coins, level),
        _tour(context, sid, wornKey, owned, wardrobe, level, fans),
      ]),
    );
  }

  // ───────────────────────────── ON STAGE ─────────────────────────────
  Widget _onStage(
      BuildContext context,
      String sid,
      String wornKey,
      List<String> owned,
      Wardrobe wardrobe,
      Venue venue,
      int level,
      int fans,
      int coins) {
    final text = Theme.of(context).textTheme;
    final venueIndex = venues.indexOf(venue);
    return Stack(fit: StackFit.expand, children: [
      artAsset('venue_$venueIndex', fit: BoxFit.cover),
      Container(color: Colors.white.withValues(alpha: 0.25)),
      SafeArea(
        child: Column(children: [
          // Marquee: venue + totals.
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: JamJotColors.ink, width: 2),
            ),
            child: Row(children: [
              Expanded(
                child: Text('Level $level — ${venue.name}',
                    style:
                        text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('🪙 $coins   🕶️ $fans',
                  style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800, color: JamJotColors.ink)),
            ]),
          ),
          const Spacer(),
          // The band on stage: the spotlight member stands tall and
          // centered under the venue's painted beam with a marquee
          // nameplate; the rest wait in the wings, out of the light,
          // unlabeled until their turn comes.
          LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final starSize = (w * 0.26).clamp(150.0, 260.0);
            final sideSize = (starSize * 0.56).clamp(84.0, 150.0);
            const plateRoom = 54.0; // nameplate + gap under the stage line
            final stageH = starSize + plateRoom + 10;
            final others =
                owned.where((k) => k != wornKey).toList(growable: false);
            // Alternate wings: first understudy stage-right, next
            // stage-left, working outward from the beam, feet on the
            // star's stage line. Clamped so nobody walks off screen.
            double centerXFor(int i) {
              final dir = i.isEven ? 1.0 : -1.0;
              final rank = i ~/ 2;
              final x = w / 2 +
                  dir * (starSize * 0.62 + sideSize * (0.55 + 0.82 * rank));
              return x
                  .clamp(sideSize * 0.55 + 8, w - sideSize * 0.55 - 8)
                  .toDouble();
            }

            return SizedBox(
              height: stageH,
              width: double.infinity,
              child: Stack(clipBehavior: Clip.none, children: [
                for (var i = 0; i < others.length; i++)
                  AnimatedPositioned(
                    key: ValueKey('wing_${others[i]}'),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    bottom: plateRoom,
                    left: centerXFor(i) - sideSize / 2,
                    child: GestureDetector(
                      onTap: () => _choose(sid, others[i]),
                      child: Opacity(
                        opacity: 0.8,
                        child: DressedAvatar(
                            avatarKey: others[i],
                            outfit: wardrobe.outfitFor(others[i]),
                            size: sideSize),
                      ),
                    ),
                  ),
                // The star: biggest, dead-center under the beam.
                Positioned(
                  key: ValueKey('star_$wornKey'),
                  bottom: plateRoom,
                  left: w / 2 - starSize / 2,
                  child: GestureDetector(
                    onTap: () => _choose(sid, wornKey),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFFFF0C9)
                                  .withValues(alpha: 0.85),
                              offset: const Offset(0, 12),
                              blurRadius: 34,
                              spreadRadius: 6),
                        ],
                      ),
                      child: _CheerBurst(
                        active: true,
                        seq: _cheerSeq,
                        child: DressedAvatar(
                            avatarKey: wornKey,
                            outfit: wardrobe.outfitFor(wornKey),
                            size: starSize),
                      ),
                    ),
                  ),
                ),
                // Marquee nameplate: the spotlight name in lights,
                // scaled down rather than ever cut off.
                Positioned(
                  bottom: 4,
                  left: 12,
                  right: 12,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white, Color(0xFFFFF4DA)]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: venue.accent, width: 3),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x33000000),
                                offset: Offset(0, 3),
                                blurRadius: 8),
                          ],
                        ),
                        child: Text('✨ ${_avatarName(wornKey)} ✨',
                            maxLines: 1,
                            style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                color: JamJotColors.ink)),
                      ),
                    ),
                  ),
                ),
              ]),
            );
          }),
          // Their crowd at the stage edge, in true scale.
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 4),
            child: CrowdStrip(
                fans: fans,
                height: 46,
                full: level < venues.length
                    ? venues[level].minFans
                    : venue.minFans),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              owned.length == 1
                  ? 'Tap your musician to cheer — new band members join from the Market!'
                  : 'Tap a band member to put them in the spotlight',
              style: text.labelSmall?.copyWith(
                  color: JamJotColors.ink, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _choose(String sid, String key) async {
    final active = ref.read(activeStudentProvider);
    if (active?['avatar_key'] == key) {
      // Already in the spotlight: tapping them is a cheer, as promised.
      playSound('cheer');
      setState(() => _cheerSeq++);
      return;
    }
    var ok = false;
    if (key != 'sonatina') {
      try {
        final data = Map<String, dynamic>.from(await JamJotBackend.client
            .rpc('wear_owned_avatar',
                params: {'p_student_id': sid, 'p_asset_key': key}));
        ok = data['ok'] == true;
      } catch (_) {/* fall through to direct update */}
    }
    if (!ok) {
      try {
        await JamJotBackend.client
            .from('students')
            .update({'avatar_key': key}).eq('id', sid);
        ok = true;
      } catch (_) {}
    }
    if (!ok || !mounted) return;
    ref.invalidate(myStudentsProvider);
    if (active?['id'] == sid) {
      ref.read(activeStudentProvider.notifier).state = {
        ...active!,
        'avatar_key': key,
      };
    }
  }

  // ─────────────────────────── DRESSING ROOM ───────────────────────────
  Widget _dressingRoom(BuildContext context, String sid, String wornKey,
      List<String> owned,
      Wardrobe wardrobe, int coins, int level) {
    final text = Theme.of(context).textTheme;
    final outfit = wardrobe.outfitFor(wornKey);
    return Container(
      // Backstage: deep velvet walls behind everything.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF55303C), Color(0xFF3A2029)],
        ),
      ),
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // The backstage mirror: a star on the door, bulbs up top, and a
        // brass name plate under the glass.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E7),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: venueFor(displayedFans(ref, sid)).$2.accent,
                width: 3),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33F5B82E), blurRadius: 18, spreadRadius: 2),
            ],
          ),
          child: Column(children: [
            const _MirrorBulbs(),
            const SizedBox(height: 8),
            // The looking glass: an arched mirror with bulbs down the sides.
            Stack(alignment: Alignment.center, children: [
              Container(
                width: 230,
                height: 212,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    center: Alignment(-0.4, -0.5),
                    radius: 1.2,
                    colors: [Color(0xFFFEFCF5), Color(0xFFDFE5E2)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(115), bottom: Radius.circular(18)),
                  border: Border.all(color: const Color(0xFF8A5A33), width: 5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 8),
                  ],
                ),
              ),
              for (final side in const [-1, 1])
                for (var i = 0; i < 3; i++)
                  Positioned(
                    left: side < 0 ? 12 : null,
                    right: side > 0 ? 12 : null,
                    top: 42 + i * 58.0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                            colors: [Color(0xFFFFF3C2), Color(0xFFF5B82E)]),
                        boxShadow: [
                          BoxShadow(
                              color: Color(0x66F5B82E),
                              blurRadius: 9,
                              spreadRadius: 1),
                        ],
                      ),
                    ),
                  ),
              DressedAvatar(
                  avatarKey: wornKey,
                  outfit: outfit,
                  ghost: _ghost,
                  size: 170),
            ]),
            const SizedBox(height: 2),
            // The vanity shelf under the glass, props and all.
            Container(
              width: 250,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF8A5A33),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: JamJotColors.ink, width: 1.5),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text('🎀  🪮  🧴', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 8),
            // The star's name plate.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5E6BC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: JamJotColors.ink, width: 2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('⭐ ', style: TextStyle(fontSize: 13)),
                Text(_avatarName(wornKey),
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(height: 4),
            Text(
                outfit.isEmpty
                    ? 'Fresh from the garden — try something on!'
                    : 'Wearing ${outfit.length} item${outfit.length == 1 ? '' : 's'}',
                style: text.bodySmall),
          ]),
        ),
        const SizedBox(height: 14),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: Text('The Band',
                style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ]),
        Text('New members join the band as you tour the world! 🚌',
            style: text.bodySmall?.copyWith(color: const Color(0xFFE8D7C3))),
        const SizedBox(height: 8),
        Row(children: [
          for (final key in owned) ...[
            Expanded(child: _bandMemberCard(context, sid, key, wornKey)),
            if (key != owned.last) const SizedBox(width: 10),
          ],
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Text('The Costume Rack',
                style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          if (accessoryCatalog.isNotEmpty)
            Text(
                '${wardrobe.owned.length} of ${accessoryCatalog.length} collected',
                style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF5B82E))),
        ]),
        Text(
            accessoryCatalog.isEmpty
                ? 'The costume department is sewing a whole new wardrobe '
                    'for the World Tour — arriving soon! 🧵'
                : 'Everything you own dresses ANY band member. 🪙 $coins to spend.',
            style: text.bodySmall?.copyWith(color: const Color(0xFFE8D7C3))),
        const SizedBox(height: 8),
        // A real wardrobe: a wooden case with shelves, four smaller
        // pieces standing on each shelf.
        Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
          decoration: BoxDecoration(
            color: const Color(0xFF6E4426),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: JamJotColors.ink, width: 3),
          ),
          child: Column(children: [
            for (var row = 0; row * 4 < accessoryCatalog.length; row++) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var col = 0; col < 4; col++) ...[
                      if (col > 0) const SizedBox(width: 6),
                      Expanded(
                        child: row * 4 + col < accessoryCatalog.length
                            ? _closetTile(context, sid, wornKey, wardrobe,
                                accessoryCatalog[row * 4 + col], coins, level)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
              // The shelf each row of pieces stands on.
              Container(
                height: 7,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9A6A3C),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: JamJotColors.ink, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x55000000), offset: Offset(0, 2)),
                  ],
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        // A backstage word from the maestro.
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: JamJotColors.ink, width: 2),
          ),
          child: Row(children: [
            Image.asset('assets/mascot/maestro_tux.png', width: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                accessoryCatalog.isEmpty
                    ? '"The tailors are hard at work, mon ami — a world tour '
                        'deserves a world-class wardrobe!" — Maestro Marmalade'
                    : wardrobe.owned.length >= accessoryCatalog.length
                        ? '"A full wardrobe! Magnifique — now THAT is a star." '
                            '— Maestro Marmalade'
                    : '"Every great performer starts with one good hat. '
                        'Keep practicing and the closet fills itself!" '
                        '— Maestro Marmalade',
                style:
                    text.labelSmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Text(
          'Closet ownership is saved on this device for the preview — it moves '
          'to the student\'s account with the venue-world backend.',
          style: text.labelSmall
              ?.copyWith(color: const Color(0xFFE8D7C3)),
        ),
      ],
    ),
    );
  }

  /// One band member in the dressing room: who's in the spotlight, and a
  /// button to hand it over (Tour 2.0 vocabulary, JJ-017-C).
  Widget _bandMemberCard(
      BuildContext context, String sid, String key, String wornKey) {
    final text = Theme.of(context).textTheme;
    final inSpotlight = key == wornKey;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      decoration: BoxDecoration(
        color: inSpotlight ? const Color(0xFFFFF8E7) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: inSpotlight ? const Color(0xFFF5B82E) : JamJotColors.ink,
            width: inSpotlight ? 3 : 2),
      ),
      child: Column(children: [
        DressedAvatar(avatarKey: key, outfit: const [], size: 92),
        const SizedBox(height: 6),
        Text(_avatarName(key),
            textAlign: TextAlign.center,
            style: text.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        inSpotlight
            ? Text('⭐ In the spotlight',
                style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB8860B)))
            : TextButton(
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 30)),
                onPressed: () => _giveSpotlight(sid, key),
                child: const Text('Give them the spotlight'),
              ),
      ]),
    );
  }

  Future<void> _giveSpotlight(String sid, String assetKey) async {
    try {
      final data = Map<String, dynamic>.from(
          await JamJotBackend.client.rpc('wear_owned_avatar', params: {
        'p_student_id': sid,
        'p_asset_key': assetKey,
      }));
      if (!mounted) return;
      if (data['ok'] == true) {
        playSound('cheer');
        ref.invalidate(myStudentsProvider);
        final active = ref.read(activeStudentProvider);
        if (active?['id'] == sid) {
          ref.read(activeStudentProvider.notifier).state = {
            ...active!,
            'avatar_key': assetKey
          };
        }
      }
    } catch (_) {/* stays as-is */}
  }

  Widget _closetTile(BuildContext context, String sid, String wornKey,
      Wardrobe wardrobe, Accessory acc, int coins, int level) {
    final text = Theme.of(context).textTheme;
    final owned = wardrobe.owned.contains(acc.id);
    final worn = wardrobe.outfitFor(wornKey).contains(acc.id);
    final venueLocked = acc.venueLevel != null && level < acc.venueLevel! + 1;
    // Within reach right now: unlocked, purchasable, and affordable.
    final affordable =
        !owned && !venueLocked && !acc.bundleOnly && coins >= acc.price;
    // The story behind the piece: hover on desktop, long-press on touch.
    final tile = InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (owned) {
          ref.read(wardrobeProvider(sid).notifier).toggleWear(wornKey, acc.id);
        } else {
          setState(() => _ghost = acc.id);
          _lockedSheet(context, sid, acc, coins, venueLocked);
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
        decoration: BoxDecoration(
          color: owned
              ? Colors.white
              : affordable
                  ? const Color(0xFFFFF8E7)
                  : const Color(0xFFEFE8DA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: worn
                  ? JamJotColors.marigold
                  : affordable
                      ? JamJotColors.marigold
                      : JamJotColors.ink,
              width: worn ? 3 : affordable ? 2.5 : 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: owned
                  ? 1
                  : affordable
                      ? 0.95
                      : 0.35,
              child: artAsset('acc_icon_${acc.id}', width: 34, height: 34),
            ),
            const SizedBox(height: 4),
            Text(acc.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: owned ? JamJotColors.ink : JamJotColors.inkSoft)),
            const SizedBox(height: 2),
            if (worn)
              Text('WEARING',
                  style: text.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: JamJotColors.marigold))
            else if (owned)
              Text('tap to wear', style: text.labelSmall)
            else if (acc.bundleOnly)
              Text('🎁 ${_bundleSource(acc.id)}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall)
            else if (venueLocked)
              Text('🔒 ${venueNameForAccessory(acc)}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall)
            else
              Text('🪙 ${acc.price}',
                  style: text.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: affordable
                          ? const Color(0xFFB07A10)
                          : JamJotColors.inkSoft)),
          ],
        ),
      ),
    );
    if (acc.lore.isEmpty) return tile;
    return Tooltip(
      message: '${acc.emoji} ${acc.name}\n${acc.lore}',
      waitDuration: const Duration(milliseconds: 400),
      showDuration: const Duration(seconds: 5),
      textAlign: TextAlign.center,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: JamJotColors.ink,
        borderRadius: BorderRadius.circular(12),
      ),
      child: tile,
    );
  }

  /// The active member stands center; the rest flank them evenly, so the
  /// spotlight holder is always under the venue's painted beam.
  List<String> _stageOrder(List<String> owned, String wornKey) {
    final others = owned.where((k) => k != wornKey).toList();
    final left = <String>[];
    final right = <String>[];
    for (var i = 0; i < others.length; i++) {
      (i.isEven ? right : left).add(others[i]);
    }
    return [...left.reversed, if (owned.contains(wornKey)) wornKey, ...right];
  }

  /// Which band member an accessory arrives with.
  String _bundleSource(String accessoryId) {
    for (final entry in avatarBundles.entries) {
      if (entry.value.contains(accessoryId)) return _avatarName(entry.key);
    }
    return 'an avatar';
  }

  void _lockedSheet(BuildContext context, String sid, Accessory acc,
      int coins, bool venueLocked) {
    final text = Theme.of(context).textTheme;
    showModalBottomSheet(
      context: context,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          artAsset('acc_icon_${acc.id}', width: 58, height: 58),
          Text(acc.name,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          if (acc.lore.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(acc.lore,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: JamJotColors.inkSoft)),
          ],
          const SizedBox(height: 6),
          if (acc.bundleOnly) ...[
            Text(
                'This one comes only with ${_bundleSource(acc.id)} — '
                'earn them in the Market and it\'s yours!',
                textAlign: TextAlign.center,
                style: text.bodyMedium),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.pop(sheet);
                context.go('/market');
              },
              child: const Text('Visit the Market 🧺'),
            ),
          ] else if (venueLocked) ...[
            Text(
                'A ${venueNameForAccessory(acc)} exclusive — play that stage '
                'to unlock it!',
                textAlign: TextAlign.center,
                style: text.bodyMedium),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.pop(sheet);
                _tabs.animateTo(2);
              },
              child: const Text('See the Tour 🗺️'),
            ),
          ] else ...[
            Text('🪙 ${acc.price} — you have $coins',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (coins / acc.price).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: JamJotColors.blueberryTint,
                color: JamJotColors.marigold,
              ),
            ),
            const SizedBox(height: 14),
            if (coins >= acc.price)
              FilledButton(
                onPressed: () {
                  ref.read(wardrobeProvider(sid).notifier).acquire(acc.id);
                  Navigator.pop(sheet);
                  setState(() => _ghost = null);
                },
                child: Text('Add to closet — ${acc.price} 🪙'),
              )
            else
              FilledButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  context.go('/practice');
                },
                child: const Text("Let's practice! 🎵"),
              ),
          ],
        ]),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _ghost = null);
    });
  }

  // ─────────────────────────────── TOUR ───────────────────────────────
  Widget _tour(BuildContext context, String sid, String wornKey,
      List<String> owned, Wardrobe wardrobe, int level, int fans) {
    final text = Theme.of(context).textTheme;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: venues.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // The tour poster: the bus, and how far the journey has come.
          final next = level < venues.length ? venues[level] : null;
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: JamJotColors.ink, width: 3),
            ),
            child: Row(children: [
              const MaestroTourBus(width: 96),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('The JamJot World Tour',
                        style: text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                        next == null
                            ? 'All $level stages played — you did the '
                                'whole tour! 🎉'
                            : '$level of ${venues.length} stages played · '
                                'next stop: ${next.name}',
                        style: text.bodySmall),
                  ],
                ),
              ),
            ]),
          );
        }
        final i = index - 1;
        final v = venues[i];
        final played = level >= i + 1;
        final current = level == i + 1;
        final isNext = level == i;
        final card = Opacity(
          opacity: played || isNext ? 1 : 0.5,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: current ? v.accent : JamJotColors.ink,
                  width: current ? 3 : 2),
            ),
            child: InkWell(
              onTap: played || isNext
                  ? () => _levelUpPreview(context, i, wornKey, owned)
                  : null,
              child: Column(children: [
                SizedBox(
                  height: 96,
                  width: double.infinity,
                  child: Stack(fit: StackFit.expand, children: [
                    artAsset('venue_$i', fit: BoxFit.cover),
                    if (!played)
                      Container(
                          color: Colors.white.withValues(alpha: 0.30)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(v.motif, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('${i + 1} · ${v.name}',
                              style: text.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        if (current)
                          Text('🎫 NOW PLAYING',
                              style: text.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: v.accent))
                        else if (played)
                          const Text('🎫')
                        else
                          Text('🕶️ ${v.minFans}',
                              style: text.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                      ]),
                      if (v.lore.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(v.lore,
                            style: text.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic)),
                      ],
                      if (played || isNext) ...[
                        const SizedBox(height: 4),
                        Text(v.realStage, style: text.bodySmall),
                        const SizedBox(height: 4),
                        Text(
                          'Exclusives: ${v.exclusives.map((id) => accessoryById(id)?.name ?? id).join(' · ')}',
                          style: text.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (isNext)
                          Text('${v.minFans - fans} more fans to unlock — tap '
                              'for a sneak peek!',
                              style: text.labelSmall
                                  ?.copyWith(color: JamJotColors.inkSoft)),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
          ),
        );
        // The journey path runs down the left: traveled road behind the
        // bus, dotted road ahead.
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 52,
              child: _TourPathNode(
                stop: i + 1,
                played: played,
                current: current,
                accent: v.accent,
                first: i == 0,
                last: i == venues.length - 1,
              ),
            ),
            Expanded(child: card),
          ]),
        );
      },
    );
  }

  /// The level-up moment: tour-bus wipe, venue reveal, then the band photo.
  void _levelUpPreview(BuildContext context, int venueIndex, String wornKey,
      List<String> owned) {
    final v = venues[venueIndex];
    final wardrobe = ref.read(wardrobeProvider(
            (ref.read(activeStudentProvider)?['id'] as String?) ?? ''))
        .outfits;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Level up',
      transitionDuration: const Duration(milliseconds: 2400),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, anim, _, __) {
        final busSlide = CurvedAnimation(
            parent: anim,
            curve: const Interval(0.0, 0.45, curve: Curves.easeInOut));
        final reveal = CurvedAnimation(
            parent: anim,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOutBack));
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        return Stack(alignment: Alignment.center, children: [
          // Poster card.
          FadeTransition(
            opacity: reveal,
            child: ScaleTransition(
              scale: reveal,
              child: Dialog(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: JamJotColors.ink, width: 3),
                ),
                child: SizedBox(
                  width: 340,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      height: 190,
                      width: double.infinity,
                      child: Stack(fit: StackFit.expand, children: [
                        artAsset('venue_$venueIndex', fit: BoxFit.cover),
                        // The band poses for the photo.
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final key in _stageOrder(
                                    owned.take(5).toList(), wornKey))
                                  DressedAvatar(
                                      avatarKey: key,
                                      outfit: wardrobe[key] ?? const [],
                                      size: key == wornKey ? 84 : 62),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ),
                    Container(
                      width: double.infinity,
                      color: JamJotColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(children: [
                        Text('⭐ LIVE AT ⭐',
                            style: TextStyle(
                                color: const Color(0xFFFFD66B),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                                fontSize: 12)),
                        Text(v.name.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18)),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        Text(
                            'Venue exclusives now in the closet: '
                            '${v.exclusives.map((id) => accessoryById(id)?.emoji ?? '').join(' ')}',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        const TisdaleImprint(height: 22, opacity: 0.2),
                        const SizedBox(height: 6),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Encore! 🎉'),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          // The tour bus drives across on its way to the new venue.
          Positioned(
            bottom: 110,
            left: -140 + (screenWidth + 280) * busSlide.value,
            child: Opacity(
              opacity: anim.value < 0.5 ? 1 : (1 - (anim.value - 0.5) * 4)
                  .clamp(0.0, 1.0),
              child: const Text('🚌💨', style: TextStyle(fontSize: 56)),
            ),
          ),
        ]);
      },
    );
  }
}


/// A row of warm little vanity-mirror bulbs across the top of the
/// dressing-room mirror — real backstage style, one strip only.
class _MirrorBulbs extends StatelessWidget {
  const _MirrorBulbs();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < 7; i++)
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                  colors: [Color(0xFFFFF3C2), Color(0xFFF5B82E)]),
              boxShadow: [
                BoxShadow(
                    color: Color(0x66F5B82E),
                    blurRadius: 10,
                    spreadRadius: 1.5),
              ],
            ),
          ),
      ],
    );
  }
}


/// A quick hooray when the kid taps their musician in the spotlight: the
/// avatar does a happy hop while notes and stars burst up and fade.
class _CheerBurst extends StatefulWidget {
  const _CheerBurst(
      {required this.child, required this.seq, required this.active});
  final Widget child;
  final int seq;
  final bool active;
  @override
  State<_CheerBurst> createState() => _CheerBurstState();
}

class _CheerBurstState extends State<_CheerBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didUpdateWidget(covariant _CheerBurst old) {
    super.didUpdateWidget(old);
    if (widget.active && widget.seq != old.seq) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _sparks = ['🎶', '⭐', '🎵', '✨', '🎶'];

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final hopping = _c.isAnimating;
        // Two quick hops.
        final hop = hopping
            ? -14 *
                (math.sin(t * math.pi * 2).abs() * (1 - t)).toDouble()
            : 0.0;
        return Stack(clipBehavior: Clip.none, alignment: Alignment.center,
            children: [
          Transform.translate(offset: Offset(0, hop), child: child),
          if (hopping)
            for (var i = 0; i < _sparks.length; i++)
              Positioned(
                top: -8 - t * (44 + 14 * i % 3),
                left: 18.0 + i * 24,
                child: Opacity(
                  opacity: ((1 - t) * 1.4).clamp(0.0, 1.0),
                  child: Text(_sparks[i],
                      style: TextStyle(fontSize: 16 + (i % 3) * 4)),
                ),
              ),
        ]);
      },
      child: widget.child,
    );
  }
}


/// One stop on the tour path: road above and below, and either a stamped
/// stop dot or the tour bus parked at the current stage.
class _TourPathNode extends StatelessWidget {
  const _TourPathNode(
      {required this.stop,
      required this.played,
      required this.current,
      required this.accent,
      required this.first,
      required this.last});
  final int stop;
  final bool played;
  final bool current;
  final Color accent;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final roadDone = JamJotColors.ink;
    final roadAhead = JamJotColors.ink.withValues(alpha: 0.25);
    return Column(children: [
      Expanded(
          child: first
              ? const SizedBox.shrink()
              : _Road(color: played ? roadDone : roadAhead, dashed: !played)),
      if (current)
        const MaestroTourBus(width: 58)
      else
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: played ? accent : Colors.white,
            border: Border.all(
                color: played ? JamJotColors.ink : roadAhead, width: 2.5),
          ),
          child: played
              ? const Icon(Icons.check, size: 15, color: Colors.white)
              : Text('$stop',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: roadAhead)),
        ),
      Expanded(
          child: last
              ? const SizedBox.shrink()
              : _Road(
                  color: played && !current ? roadDone : roadAhead,
                  dashed: !(played && !current))),
    ]);
  }
}

/// A short stretch of tour road: solid where the bus has been, dotted ahead.
class _Road extends StatelessWidget {
  const _Road({required this.color, required this.dashed});
  final Color color;
  final bool dashed;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(4, double.infinity),
          painter: _RoadPainter(color, dashed));
}

class _RoadPainter extends CustomPainter {
  const _RoadPainter(this.color, this.dashed);
  final Color color;
  final bool dashed;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    if (!dashed) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      return;
    }
    var y = 2.0;
    while (y < size.height) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + 6).clamp(0, size.height)),
          paint);
      y += 13;
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) =>
      old.color != color || old.dashed != dashed;
}

// (The old side-view _RollingBus was replaced by MaestroTourBus —
// Maestro Marmalade driving the founder's purple bus, with a hover/tap
// honk-and-idle animation. See lib/widgets/maestro_tour_bus.dart.)
