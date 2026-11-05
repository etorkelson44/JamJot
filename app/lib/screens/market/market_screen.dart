import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../services/sound_effects.dart';
import '../../models/market_avatars.dart';
import '../../widgets/letter_avatar.dart';
import '../../widgets/dressed_avatar.dart';
import '../../state/wardrobe.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/coin_pouch.dart';
import '../../widgets/fan_stage.dart';
import '../../widgets/stickers.dart';

/// Every stand this person may browse.
final marketItemsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await JamJotBackend.client
      .from('market_items')
      .select()
      .eq('active', true)
      .order('price', ascending: true);
  return presentMarketItems(rows.cast<Map<String, dynamic>>(),
      includeUpcoming:
          kIsWeb && {'localhost', '127.0.0.1', '::1'}.contains(Uri.base.host));
});

/// Everything a student has bought (their Shelf).
final purchasesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, studentId) async {
  final rows = await JamJotBackend.client
      .from('purchases')
      .select('*, market_items(title, emoji, kind, asset_key, stand)')
      .eq('student_id', studentId)
      .order('created_at', ascending: false);
  return rows.cast<Map<String, dynamic>>();
});

/// Ready-made reward ideas grown-ups can stock with one tap.
const familyRewardIdeas = [
  ('🍦', 'Ice cream trip', 60, 'outing'),
  ('🍕', 'Pick what we eat for dinner', 50, 'privilege'),
  ('🎬', 'Family movie night — your pick', 60, 'outing'),
  ('🕹️', '30 extra minutes of screen time', 40, 'privilege'),
  ('🦉', 'Stay up 15 minutes later', 35, 'privilege'),
  ('🧹', 'Skip one chore', 45, 'privilege'),
  ('🛏️', 'Sleepover with a friend', 120, 'outing'),
  ('🎲', 'Game night — you choose the game', 40, 'privilege'),
  ('🧸', 'Small toy or treat (~\$5)', 100, 'treat'),
  ('🏊', 'Trip to the pool / park', 80, 'outing'),
];

const teacherRewardIdeas = [
  ('⭐', 'Sticker from the big sticker box', 10, 'treat'),
  ('🎁', 'Pick from the prize box', 50, 'treat'),
  ('🎵', 'You pick the next new song', 60, 'music'),
  ('🎹', 'Teacher plays any song you request', 30, 'music'),
  ('🎮', 'Music game time in the lesson (5 min)', 40, 'music'),
  ('🥁', 'Try a different instrument for 5 minutes', 45, 'music'),
  ('🏅', 'Studio superstar shout-out', 25, 'treat'),
];

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});
  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  bool _buying = false;
  final Map<String, String> _purchaseRequests = {};
  String? _shopperId; // which kid is shopping (grown-up view)

  Future<void> _buy(Map<String, dynamic> item, String studentId) async {
    if (_buying || item['upcoming'] == true) return;
    setState(() => _buying = true);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text('${item['emoji']} ${item['title']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (item['kind'] == 'avatar') ...[
            _marketArt(item, 112),
            const SizedBox(height: 12),
          ],
          Text(
              'Spend ${item['price']} coins on this?${item['kind'] == 'avatar' ? ' You\'ll wear it right away!' : ' A grown-up hands it over once it\'s bought.'}'),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not yet')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: CoinLabel('Buy for ${item['price']} coins'),
          ),
        ],
      ),
    );
    if (ok != true) {
      if (mounted) setState(() => _buying = false);
      return;
    }
    try {
      final key = '$studentId/${item['id']}';
      final data = Map<String, dynamic>.from(
          await JamJotBackend.client.rpc('purchase_market_item', params: {
        'p_student_id': studentId,
        'p_item_id': item['id'],
        'p_request_id':
            _purchaseRequests.putIfAbsent(key, () => const Uuid().v4()),
      }));
      _purchaseRequests.remove(key);
      if (!mounted) return;
      if (data['ok'] == true) {
        playSound('pop');
        popSticker(context, 'berry_rich', ms: 1500);
        ref.invalidate(berryBalanceProvider(studentId));
        ref.invalidate(purchasesProvider(studentId));
        ref.invalidate(myStudentsProvider);
        // A new band member brings their accessories into the closet,
        // worn from the start.
        if (item['kind'] == 'avatar' && item['asset_key'] != null) {
          ref
              .read(wardrobeProvider(studentId).notifier)
              .grantBundle(item['asset_key'] as String);
        }
        final active = ref.read(activeStudentProvider);
        if (active?['id'] == studentId && item['kind'] == 'avatar') {
          ref.read(activeStudentProvider.notifier).state = {
            ...active!,
            'avatar_key': item['asset_key']
          };
        }
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
              side: JamJotShape.border,
            ),
            title: Text('${item['emoji']} It\'s yours!'),
            content: Text(item['kind'] == 'avatar'
                ? 'You\'re wearing it now — check your profile!'
                : 'It\'s on your Shelf. Show a grown-up so they can make it happen!'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
                child: const Text('🎉'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text((data['error'] as String?) ?? 'Could not buy just now.')));
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not confirm the purchase. Check My Shelf before trying again.')));
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _wear(String studentId, String assetKey) async {
    try {
      final data = Map<String, dynamic>.from(
          await JamJotBackend.client.rpc('wear_owned_avatar', params: {
        'p_student_id': studentId,
        'p_asset_key': assetKey,
      }));
      if (!mounted) return;
      if (data['ok'] == true) {
        ref.invalidate(myStudentsProvider);
        final active = ref.read(activeStudentProvider);
        if (active?['id'] == studentId) {
          ref.read(activeStudentProvider.notifier).state = {
            ...active!,
            'avatar_key': assetKey
          };
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Looking good! 😎')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text((data['error'] as String?) ?? 'Could not change it.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Your avatar could not be changed. Try again.')));
      }
    }
  }

  Future<void> _stockStand({required String stand, String? teacherId}) async {
    final ideas = stand == 'teacher' ? teacherRewardIdeas : familyRewardIdeas;
    final title = TextEditingController();
    final emoji = TextEditingController(text: '🎁');
    final price = TextEditingController(text: '50');
    var kind = 'treat';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
            side: JamJotShape.border,
          ),
          title: const Text('Stock your stand'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ideas (tap to use):',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final (e, t, p, k) in ideas)
                      ActionChip(
                        avatar: Text(e),
                        label: Text(t, style: const TextStyle(fontSize: 12)),
                        onPressed: () => setState(() {
                          emoji.text = e;
                          title.text = t;
                          price.text = '$p';
                          kind = k;
                        }),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    SizedBox(
                      width: 64,
                      child: TextField(
                        controller: emoji,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(labelText: 'Emoji'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: title,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Reward'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Price in coins'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
              child: const Text('Put it on the stand'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || title.text.trim().isEmpty) return;
    try {
      final uid = JamJotBackend.client.auth.currentUser!.id;
      await JamJotBackend.client.from('market_items').insert({
        'stand': stand,
        'owner_id': uid,
        'title': title.text.trim(),
        'emoji': emoji.text.trim().isEmpty ? '🎁' : emoji.text.trim(),
        'price': int.tryParse(price.text.trim()) ?? 50,
        'kind': kind,
      });
      ref.invalidate(marketItemsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not stock that — only primary caregivers (or caregivers given the reward permission) can stock the family stand.')));
      }
    }
  }

  Widget _marketArt(Map<String, dynamic> item, double size) {
    final key = item['asset_key'] as String?;
    if (item['kind'] == 'avatar' &&
        key != null &&
        berryAvatars.containsKey(key)) {
      // Shown wearing the accessories they come with (JJ-014 revision).
      return ExcludeSemantics(
          child: DressedAvatar(
              avatarKey: key,
              outfit: avatarBundles[key] ?? const [],
              size: size));
    }
    return ExcludeSemantics(
        child: Text(item['emoji'] as String? ?? '🎁',
            style: const TextStyle(fontSize: 26)));
  }

  Widget _musicalAvatarCards(
      List<Map<String, dynamic>> items,
      String? shopperId,
      List<Map<String, dynamic>> purchases,
      String? wearing) {
    final featured = [
      for (final key in musicalAvatars.keys)
        ...items.where((i) => i['kind'] == 'avatar' && i['asset_key'] == key)
    ];
    if (featured.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = (constraints.maxWidth / 260).floor().clamp(1, 4);
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final item in featured)
            SizedBox(
                width: width,
                child: Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: _marketArt(item, 168)),
                          const SizedBox(height: 12),
                          Text(item['title'] as String,
                              style: theme.textTheme.titleLarge,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Text(item['description'] as String,
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          _avatarAction(item, shopperId, purchases, wearing),
                        ],
                      )),
                )),
        ]);
      }),
    );
  }

  Widget _avatarAction(Map<String, dynamic> item, String? shopperId,
      List<Map<String, dynamic>> purchases, String? wearing) {
    final owned = purchases.any((p) =>
        (p['market_items'] as Map?)?['kind'] == 'avatar' &&
        (p['market_items'] as Map?)?['asset_key'] == item['asset_key']);
    final isWearing = owned && wearing == item['asset_key'];
    final upcoming = item['upcoming'] == true;
    final price = (item['price'] as num).toInt();
    final label = upcoming
        ? 'Coming soon · $price coins'
        : isWearing
            ? 'Wearing ✓'
            : owned
                ? 'Wear it'
                : 'Buy · $price coins';
    return FilledButton(
      onPressed: upcoming || isWearing || _buying || shopperId == null
          ? null
          : () => owned
              ? _wear(shopperId, item['asset_key'] as String)
              : _buy(item, shopperId),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: owned
              ? Text(label, textAlign: TextAlign.center)
              : CoinLabel(label)),
    );
  }

  Widget _itemTile(Map<String, dynamic> item, String? shopperId,
      {bool mine = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JamJotColors.outline, width: 1.5),
      ),
      child: Row(children: [
        _marketArt(item, 56),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['title'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if ((item['description'] as String?)?.isNotEmpty == true)
                Text(item['description'] as String,
                    style: const TextStyle(
                        fontSize: 12, color: JamJotColors.inkSoft)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          CoinPrice((item['price'] as num).toInt()),
          if (shopperId != null)
            TextButton(
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 30)),
              onPressed: _buying ? null : () => _buy(item, shopperId),
              child: const Text('Buy'),
            )
          else if (mine)
            TextButton(
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 30)),
              onPressed: () async {
                await JamJotBackend.client
                    .from('market_items')
                    .update({'active': false}).eq('id', item['id']);
                ref.invalidate(marketItemsProvider);
              },
              child: const Text('Take down',
                  style: TextStyle(color: JamJotColors.recording)),
            ),
        ]),
      ]),
    );
  }

  Widget _standHeader(TextTheme text, String emoji, String title,
      {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        if (action != null) action,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final activeKid = ref.watch(activeStudentProvider);
    final kids = ref.watch(myStudentsProvider).valueOrNull ?? [];
    final teacher = ref.watch(myTeacherProvider).valueOrNull;
    final items = ref.watch(marketItemsProvider).valueOrNull ?? [];
    final uid = JamJotBackend.client.auth.currentUser?.id;

    // Who's shopping?
    final shopper = activeKid ??
        (kids.where((k) => k['id'] == _shopperId).firstOrNull ??
            (kids.length == 1 ? kids.first : null));
    final shopperId = shopper?['id'] as String?;

    final jamjotItems = items.where((i) => i['stand'] == 'jamjot').toList();
    final teacherItems = items.where((i) => i['stand'] == 'teacher').toList();
    final familyItems = items.where((i) => i['stand'] == 'caregiver').toList();

    final purchases = shopperId == null
        ? <Map<String, dynamic>>[]
        : (ref.watch(purchasesProvider(shopperId)).valueOrNull ?? []);
    final iAmGrownUp = activeKid == null;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(children: [
            Expanded(
              child: Text("Farmers' Market",
                  style: text.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            // Kids already carry the corner Jam Jar chip; the big header
            // jar stays for grown-ups shopping on a kid's behalf.
            if (shopperId != null && iAmGrownUp)
              JamJar(studentId: shopperId, big: true),
          ]),
          const SizedBox(height: 4),
          Text(
            'Practice fills your Jam Jar — spend your coins at the stands!',
            style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
          ),
          if (iAmGrownUp && kids.length > 1) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, children: [
              for (final k in kids)
                ChoiceChip(
                  label: Text(k['display_name'] as String),
                  selected: shopperId == k['id'],
                  selectedColor: JamJotColors.blueberryTint,
                  onSelected: (_) =>
                      setState(() => _shopperId = k['id'] as String),
                ),
            ]),
          ],
          if (shopperId != null) ...[
            const SizedBox(height: 12),
            FanStage(studentId: shopperId, compact: true),
          ],

          // ------------------------------------------------ JamJot stand
          _standHeader(text, '🫐', 'JamJot stand — musical avatars'),
          Text('Wear a new character everywhere in the app.',
              style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
          const SizedBox(height: 6),
          _musicalAvatarCards(jamjotItems, shopperId, purchases,
              shopper?['avatar_key'] as String?),
          for (final i in jamjotItems)
            if (!musicalAvatars.containsKey(i['asset_key']) ||
                i['kind'] != 'avatar')
              _itemTile(i, shopperId),

          // -------------------------------------------- Tour exclusives
          if (shopperId != null) ...[
            _standHeader(text, '🚌', 'Tour exclusives'),
            Text(
                'One-of-a-kind pieces earned on the JamJot World Tour — '
                'each one unlocks when you play its venue.',
                style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
            const SizedBox(height: 6),
            _TourExclusivesStand(studentId: shopperId),
          ],

          // ----------------------------------------------- Teacher stands
          if (teacherItems.isNotEmpty || teacher != null)
            _standHeader(text, '🎵', "Teacher's stand",
                action: teacher == null
                    ? null
                    : TextButton.icon(
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size(0, 32)),
                        onPressed: () => _stockStand(stand: 'teacher'),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Stock'),
                      )),
          if (teacher != null && teacherItems.isEmpty)
            Text('Your stand is empty — stock rewards your students can earn!',
                style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
          for (final i in teacherItems)
            _itemTile(i, shopperId, mine: i['owner_id'] == uid),

          // ------------------------------------------- My Grownups' stand
          if (kids.isNotEmpty || familyItems.isNotEmpty)
            _standHeader(text, '🏡', "My Grownups' stand",
                action: iAmGrownUp
                    ? TextButton.icon(
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size(0, 32)),
                        onPressed: () => _stockStand(stand: 'caregiver'),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Stock'),
                      )
                    : null),
          if (familyItems.isEmpty && kids.isNotEmpty)
            Text(
                iAmGrownUp
                    ? 'Nothing stocked yet — add rewards your kids can save up for (tap Stock for ready-made ideas).'
                    : 'Ask your grown-up to stock their stand with rewards!',
                style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
          for (final i in familyItems)
            _itemTile(i, shopperId, mine: i['owner_id'] == uid),

          // ------------------------------------------------------ My Shelf
          if (shopperId != null) ...[
            _standHeader(text, '🧺', "${shopper!['display_name']}'s Shelf"),
            if (purchases.isEmpty)
              Text('Nothing bought yet — the stands await!',
                  style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
            for (final p in purchases)
              Builder(builder: (context) {
                final mi = presentMarketAvatar(Map<String, dynamic>.from(
                    (p['market_items'] as Map?) ?? {}));
                final isAvatar = mi['kind'] == 'avatar';
                final pending = p['status'] == 'pending';
                final wearing = shopper['avatar_key'] == mi['asset_key'] &&
                    mi['asset_key'] != null;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: JamJotColors.blueberryTint,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: JamJotColors.outline, width: 1.5),
                  ),
                  child: Row(children: [
                    _marketArt(mi, 64),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mi['title'] as String? ?? 'Reward',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            pending
                                ? 'Waiting for a grown-up to make it happen'
                                : DateFormat('MMM d').format(
                                    DateTime.parse(p['created_at'] as String)
                                        .toLocal()),
                            style: const TextStyle(
                                fontSize: 12, color: JamJotColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    if (isAvatar)
                      wearing
                          ? const Text('Wearing ✓',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: JamJotColors.inkSoft))
                          : TextButton(
                              style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  minimumSize: const Size(0, 30)),
                              onPressed: () => _wear(
                                  shopperId, mi['asset_key'] as String? ?? ''),
                              child: const Text('Wear it'),
                            )
                    else if (pending && iAmGrownUp)
                      TextButton(
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size(0, 30)),
                        onPressed: () async {
                          await JamJotBackend.client.from('purchases').update(
                              {'status': 'fulfilled'}).eq('id', p['id']);
                          ref.invalidate(purchasesProvider(shopperId));
                        },
                        child: const Text('Mark given ✓'),
                      ),
                  ]),
                );
              }),
          ] else if (kids.isEmpty && teacher == null) ...[
            const SizedBox(height: 20),
            Text(
              'The market opens once you have students or kids connected.',
              style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
            ),
          ],
        ],
      ),
    );
  }
}


/// The venue-exclusive accessories, shown in the market as tour goals:
/// each card carries its venue, its story, and how to earn it. Unlocked
/// pieces can be bought here with coins; the rest are the reason to
/// keep practicing.
class _TourExclusivesStand extends ConsumerWidget {
  const _TourExclusivesStand({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final wardrobe = ref.watch(wardrobeProvider(studentId));
    final coins =
        ref.watch(berryBalanceProvider(studentId)).valueOrNull ?? 0;
    final fans = displayedFans(ref, studentId);
    final (level, _) = venueFor(fans);
    final exclusives = [
      for (final a in accessoryCatalog)
        if (a.venueLevel != null && !a.bundleOnly) a
    ];
    return Column(children: [
      for (final acc in exclusives)
        Builder(builder: (context) {
          final venue = venues[acc.venueLevel!];
          final unlocked = level >= acc.venueLevel! + 1;
          final owned = wardrobe.owned.contains(acc.id);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: unlocked ? venue.accent : JamJotColors.ink,
                  width: 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The venue the piece belongs to, as its backdrop.
                SizedBox(
                  width: 86,
                  child: Stack(fit: StackFit.expand, children: [
                    artAsset('venue_${acc.venueLevel}', fit: BoxFit.cover),
                    if (!unlocked)
                      Container(color: Colors.white.withValues(alpha: 0.35)),
                    Center(
                        child: artAsset('acc_icon_${acc.id}',
                            width: 52, height: 52)),
                  ]),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(acc.name,
                                style: text.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800)),
                          ),
                          if (owned)
                            Text('In your closet ✓',
                                style: text.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: venue.accent))
                          else if (unlocked)
                            Text('🪙 ${acc.price}',
                                style: text.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800))
                          else
                            Text('🔒 🕶️ ${venue.minFans}',
                                style: text.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 2),
                        Text('${venue.motif} A ${venue.name} exclusive',
                            style: text.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (acc.lore.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(acc.lore,
                              style: text.labelSmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: JamJotColors.inkSoft)),
                        ],
                        const SizedBox(height: 6),
                        if (owned)
                          Text('Dress any band member in the Dressing Room.',
                              style: text.labelSmall)
                        else if (unlocked && coins >= acc.price)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact),
                              onPressed: () {
                                ref
                                    .read(wardrobeProvider(studentId)
                                        .notifier)
                                    .acquire(acc.id);
                                playSound('pop');
                              },
                              child:
                                  Text('Add to closet — ${acc.price} 🪙'),
                            ),
                          )
                        else if (unlocked)
                          Text(
                              'Earn ${acc.price - coins} more coin'
                              '${acc.price - coins == 1 ? '' : 's'} in '
                              'practice to bring it home.',
                              style: text.labelSmall)
                        else
                          Text(
                              'Play ${venue.name} to unlock — '
                              '${venue.minFans - fans > 0 ? '${venue.minFans - fans} more fans to go!' : 'almost there!'}',
                              style: text.labelSmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
    ]);
  }
}
