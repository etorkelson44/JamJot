import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/coin_pouch.dart';
import '../../widgets/fan_stage.dart';

/// Every stand this person may browse.
final marketItemsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await JamJotBackend.client
      .from('market_items')
      .select()
      .eq('active', true)
      .order('price', ascending: true);
  return rows.cast<Map<String, dynamic>>();
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
  String? _shopperId; // which kid is shopping (grown-up view)

  Future<void> _buy(Map<String, dynamic> item, String studentId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text('${item['emoji']} ${item['title']}'),
        content: Text(
            'Spend ${item['price']} coins on this?${item['kind'] == 'avatar' ? ' You\'ll wear it right away!' : ' A grown-up hands it over once it\'s bought.'}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not yet')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: Text('Buy for 🪙 ${item['price']}'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await JamJotBackend.client.functions
          .invoke('buy-item', body: {
        'student_id': studentId,
        'item_id': item['id'],
      });
      final data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      if (!mounted) return;
      if (data['ok'] == true) {
        ref.invalidate(berryBalanceProvider(studentId));
        ref.invalidate(purchasesProvider(studentId));
        ref.invalidate(myStudentsProvider);
        ref.invalidate(activeStudentProvider);
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
                style:
                    FilledButton.styleFrom(minimumSize: const Size(96, 44)),
                child: const Text('🎉'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                (data['error'] as String?) ?? 'Could not buy just now.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not reach the market — try again?')));
      }
    }
  }

  Future<void> _wear(String studentId, String assetKey) async {
    try {
      final res = await JamJotBackend.client.functions.invoke('buy-item',
          body: {
            'student_id': studentId,
            'action': 'wear',
            'asset_key': assetKey
          });
      final data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      if (!mounted) return;
      if (data['ok'] == true) {
        ref.invalidate(myStudentsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Looking good! 😎')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text((data['error'] as String?) ?? 'Could not change it.')));
      }
    } catch (_) {}
  }

  Future<void> _stockStand(
      {required String stand, String? teacherId}) async {
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
                        label: Text(t,
                            style: const TextStyle(fontSize: 12)),
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
                        decoration:
                            const InputDecoration(labelText: 'Emoji'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: title,
                        textCapitalization: TextCapitalization.sentences,
                        decoration:
                            const InputDecoration(labelText: 'Reward'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Price in coins 🪙'),
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
        Text(item['emoji'] as String? ?? '🎁',
            style: const TextStyle(fontSize: 26)),
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
              onPressed: () => _buy(item, shopperId),
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
              style:
                  text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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

    final jamjotItems =
        items.where((i) => i['stand'] == 'jamjot').toList();
    final teacherItems =
        items.where((i) => i['stand'] == 'teacher').toList();
    final familyItems =
        items.where((i) => i['stand'] == 'caregiver').toList();

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
            if (shopperId != null) CoinPouch(studentId: shopperId, big: true),
          ]),
          const SizedBox(height: 4),
          Text(
            'Practice fills the coin pouch — spend it at the stands! 🪙',
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
          _standHeader(text, '🫐', 'JamJot stand — berry avatars'),
          Text('Wear a new character everywhere in the app.',
              style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
          const SizedBox(height: 6),
          for (final i in jamjotItems) _itemTile(i, shopperId),

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
                  style:
                      text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
            for (final p in purchases)
              Builder(builder: (context) {
                final mi = (p['market_items'] as Map?) ?? {};
                final isAvatar = mi['kind'] == 'avatar';
                final pending = p['status'] == 'pending';
                final wearing =
                    shopper['avatar_key'] == mi['asset_key'] &&
                        mi['asset_key'] != null;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: JamJotColors.blueberryTint,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: JamJotColors.outline, width: 1.5),
                  ),
                  child: Row(children: [
                    Text(mi['emoji'] as String? ?? '🎁',
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mi['title'] as String? ?? 'Reward',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
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
                              onPressed: () => _wear(shopperId,
                                  mi['asset_key'] as String? ?? ''),
                              child: const Text('Wear it'),
                            )
                    else if (pending && iAmGrownUp)
                      TextButton(
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size(0, 30)),
                        onPressed: () async {
                          await JamJotBackend.client
                              .from('purchases')
                              .update({'status': 'fulfilled'}).eq(
                                  'id', p['id']);
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
