import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/supabase_service.dart';
import '../../state/albums.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';
import '../../widgets/alien_fans.dart';
import '../../widgets/notestar_art.dart';
import '../../widgets/recording_player.dart';
import '../../widgets/send_email.dart';
import '../history/practice_history_screen.dart' show PracticeHistoryList;

/// The instruments of the kid whose recordings these are (for the piano
/// character, which shows only for piano players).
List<String> _kidInstruments(WidgetRef ref, String sid) {
  final active = ref.watch(activeStudentProvider);
  if (active?['id'] == sid) return instrumentsOf(active);
  final kids = ref.watch(myStudentsProvider).valueOrNull ?? const [];
  return instrumentsOf(kids.where((k) => k['id'] == sid).firstOrNull);
}

/// Recordings tab (NoteStar, 2026-11-15): Albums · Practices · Fan mail.
/// Kids land here from the tab bar; grown-ups open it from a kid's page
/// with /recordings?student=ID.
class RecordingsScreen extends ConsumerWidget {
  const RecordingsScreen({super.key, this.studentId});
  final String? studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeStudentProvider);
    final qs = GoRouterState.of(context).uri.queryParameters['student'];
    final kids = ref.watch(myStudentsProvider).valueOrNull ?? [];
    final sid = studentId ?? qs ?? active?['id'] as String?;
    final kid = active ?? kids.where((k) => k['id'] == sid).firstOrNull;
    final text = Theme.of(context).textTheme;
    if (sid == null || kid == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const StarCluster(width: 180),
                const SizedBox(height: 12),
                Text('Pick a musician on Home to see their recordings.',
                    textAlign: TextAlign.center, style: text.bodyLarge),
              ]),
            ),
          ),
        ),
      );
    }
    final name = kid['display_name'] as String;
    final isKid = active != null;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: isKid ? null : AppBar(title: Text("$name's recordings")),
        body: SafeArea(
          child: Column(children: [
            if (isKid)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 130, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Recordings', style: text.headlineMedium),
                ),
              ),
            const TabBar(
              labelColor: JamJotColors.ink,
              indicatorColor: JamJotColors.blueberry,
              indicatorWeight: 4,
              tabs: [
                Tab(text: 'Albums'),
                Tab(text: 'Practices'),
                Tab(text: 'Fan mail'),
              ],
            ),
            Expanded(
              child: TabBarView(children: [
                _AlbumsTab(studentId: sid, kidName: name),
                PracticeHistoryList(studentId: sid),
                FanMailList(studentId: sid, kidView: isKid),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab({required this.studentId, required this.kidName});
  final String studentId;
  final String kidName;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final shelf = ref.watch(albumShelfProvider(studentId));
    return shelf.when(
      loading: () => Center(
          child: InstrumentPal(
              instruments: _kidInstruments(ref, studentId),
              dancing: true,
              width: 160)),
      error: (e, _) => Center(
          child:
              Text('Could not load albums right now.', style: text.bodyLarge)),
      data: (s) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(albumShelfProvider(studentId)),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          _NextAlbumCard(shelf: s),
          const SizedBox(height: 16),
          if (s.albums.isEmpty)
            Column(children: [
              const SizedBox(height: 12),
              InstrumentPal(
                  instruments: _kidInstruments(ref, studentId),
                  pose: PianoPose.pointing,
                  width: 170),
              const SizedBox(height: 8),
              Text('Your first album is on its way!',
                  style: text.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                  'Record your songs this week (at least a minute each). '
                  'Your first and last takes become an album the night before your lesson.',
                  style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
                  textAlign: TextAlign.center),
            ]),
          for (final a in s.albums) ...[
            _AlbumTile(album: a, kidName: kidName, studentId: studentId),
            const SizedBox(height: 12),
          ],
        ]),
      ),
    );
  }
}

class _NextAlbumCard extends StatelessWidget {
  const _NextAlbumCard({required this.shelf});
  final AlbumShelf shelf;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final when = shelf.nextCutoff == null
        ? null
        : DateFormat("EEEE 'at' h:mm a").format(shelf.nextCutoff!);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JamJotColors.marigoldTint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: JamJotColors.ink, width: 2),
      ),
      child: Row(children: [
        const PaperAccent('moon_blue', size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            when == null
                ? 'Keep recording! Each week your takes become a new album.'
                : "This week's album gets made $when. "
                    '${shelf.inProgressSongs == 0 ? 'Record a song to start it!' : '${shelf.inProgressSongs} song${shelf.inProgressSongs == 1 ? '' : 's'} so far.'}',
            style: text.bodyMedium,
          ),
        ),
      ]),
    );
  }
}

/// The square paper album cover.
class AlbumCover extends StatelessWidget {
  const AlbumCover(
      {super.key, required this.volume, this.size = 84, this.piano = false});
  final int volume;
  final bool piano;
  final double size;
  static const _bg = [
    JamJotColors.marigold,
    JamJotColors.blueberryTint,
    JamJotColors.plumTint
  ];
  static const _accent = ['star_big_pink', 'moon_blue', 'star_big_lime'];
  @override
  Widget build(BuildContext context) {
    final i = volume % 3;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _bg[i],
        borderRadius: BorderRadius.circular(size * .2),
        border: Border.all(color: JamJotColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(color: JamJotColors.ink, offset: Offset(3, 3))
        ],
      ),
      child: Stack(alignment: Alignment.center, children: [
        Positioned(
            right: size * .06,
            top: size * .06,
            child: PaperAccent(_accent[i], size: size * .3)),
        Positioned(
            bottom: size * .04,
            child: piano
                ? PianoPal(pose: PianoPose.waving, width: size * .78)
                : StarBounce(size: size * .62, animate: false)),
      ]),
    );
  }
}

class _AlbumTile extends ConsumerWidget {
  const _AlbumTile(
      {required this.album, required this.kidName, required this.studentId});
  final Album album;
  final String kidName;
  final String studentId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final range =
        '${DateFormat.MMMd().format(album.from)} – ${DateFormat.MMMd().format(album.to)}';
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: JamJotColors.ink, width: 2)),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AlbumScreen(
                studentId: studentId, albumKey: album.key, kidName: kidName))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            AlbumCover(
                volume: album.volume,
                piano: playsPiano(_kidInstruments(ref, studentId))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(album.title(kidName), style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(range,
                        style: text.bodySmall
                            ?.copyWith(color: JamJotColors.inkSoft)),
                    const SizedBox(height: 2),
                    Text(
                        '${album.songs.length} song${album.songs.length == 1 ? '' : 's'}',
                        style: text.bodySmall
                            ?.copyWith(color: JamJotColors.inkSoft)),
                  ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

/// One album: every song's first take and last take.
class AlbumScreen extends ConsumerWidget {
  const AlbumScreen(
      {super.key,
      required this.studentId,
      required this.albumKey,
      required this.kidName});
  final String studentId;
  final String albumKey;
  final String kidName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final shelf = ref.watch(albumShelfProvider(studentId)).valueOrNull;
    final album = shelf?.albums.where((a) => a.key == albumKey).firstOrNull;
    if (album == null) {
      return Scaffold(
          appBar: AppBar(),
          body: Center(
              child: InstrumentPal(
                  instruments: _kidInstruments(ref, studentId),
                  dancing: true,
                  width: 160)));
    }
    final range =
        '${DateFormat.MMMd().format(album.from)} – ${DateFormat.MMMd().format(album.to)}';
    return Scaffold(
      appBar: AppBar(title: const Text('Album')),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
                child: AlbumCover(
                    volume: album.volume,
                    size: 170,
                    piano: playsPiano(_kidInstruments(ref, studentId)))),
            const SizedBox(height: 14),
            Text(album.title(kidName),
                style: text.headlineSmall, textAlign: TextAlign.center),
            Text(range,
                style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            Center(
              child: FilledButton.icon(
                onPressed: () => sendAlbumToSuperfans(
                    context, ref, studentId, album, kidName),
                icon: const Icon(Icons.favorite_outline),
                label: const Text('Send to my Superfans'),
              ),
            ),
            const SizedBox(height: 18),
            for (final song in album.songs) ...[
              _SongCard(song: song, album: album, studentId: studentId),
              const SizedBox(height: 14),
            ],
          ]),
    );
  }
}

Future<String?> _signed(String path) async {
  try {
    return await JamJotBackend.client.storage
        .from('recordings')
        .createSignedUrl(path, 3600);
  } catch (_) {
    return null;
  }
}

class _Take extends StatelessWidget {
  const _Take(
      {required this.take,
      required this.label,
      required this.color,
      this.praise});
  final AlbumTake take;
  final String label;
  final Color color;
  final String? praise;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JamJotColors.ink, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: text.titleSmall),
          const Spacer(),
          Text(DateFormat('EEE MMM d').format(take.at),
              style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
        ]),
        if (praise != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            const PaperAccent('star_big_pink', size: 22),
            const SizedBox(width: 6),
            Expanded(
                child: Text(praise!,
                    style: text.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700))),
          ]),
        ],
        const SizedBox(height: 6),
        FutureBuilder<String?>(
          future: _signed(take.path),
          builder: (context, snap) => snap.data == null
              ? const SizedBox(
                  height: 40, child: Center(child: LinearProgressIndicator()))
              : RecordingPlayer(url: snap.data!),
        ),
      ]),
    );
  }
}

class _SongCard extends ConsumerWidget {
  const _SongCard(
      {required this.song, required this.album, required this.studentId});
  final AlbumSong song;
  final Album album;
  final String studentId;

  Future<void> _swap(BuildContext context, WidgetRef ref) async {
    final options = song.takes.skip(1).toList();
    final chosen = await showModalBottomSheet<AlbumTake>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text('Pick your favorite take',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('It will play as your last take for ${song.title}.',
                  style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: 8),
              for (final t in options.reversed)
                ListTile(
                  leading: Icon(t.path == song.last.path
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off),
                  title: Text(DateFormat("EEEE 'at' h:mm a").format(t.at)),
                  subtitle: Text(
                      '${t.soundSeconds ~/ 60} min ${t.soundSeconds % 60} s of playing'),
                  onTap: () => Navigator.of(ctx).pop(t),
                ),
            ]),
      ),
    );
    if (chosen == null) return;
    try {
      await pickAlbumTake(studentId, album.key, song.assignmentId, chosen.path);
      ref.invalidate(albumShelfProvider(studentId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save that take right now.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: JamJotColors.ink, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(song.title, style: text.titleLarge),
        const SizedBox(height: 10),
        _Take(
            take: song.first, label: 'First take', color: JamJotColors.neutral),
        const SizedBox(height: 10),
        if (song.hasFinal) ...[
          _Take(
              take: song.last,
              label: 'Last take',
              color: JamJotColors.blueberryTint,
              praise: 'Listen to that progress! All that practice paid off.'),
          if (song.takes.length > 2)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _swap(context, ref),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Swap take'),
              ),
            ),
        ] else
          Row(children: [
            const PaperAccent('dot_lime', size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  'Just one take so far. Record it more than once next time and your "after" shows up here!',
                  style: text.bodyMedium),
            ),
          ]),
      ]),
    );
  }
}

/// Send an album to Superfans the grown-ups added.
Future<void> sendAlbumToSuperfans(BuildContext context, WidgetRef ref,
    String studentId, Album album, String kidName) async {
  final fans = await ref.read(superfansProvider(studentId).future);
  if (!context.mounted) return;
  if (fans.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No Superfans yet'),
        content: const Text(
            'Ask a grown-up to add your Superfans (family who love hearing you play) on your page in their account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))
        ],
      ),
    );
    return;
  }
  final picked = <String>{for (final f in fans) f['id'] as String};
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Send to your Superfans'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final f in fans)
            CheckboxListTile(
              value: picked.contains(f['id']),
              onChanged: (v) => setS(() => v == true
                  ? picked.add(f['id'] as String)
                  : picked.remove(f['id'])),
              title: Text(f['name'] as String),
            ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed:
                  picked.isEmpty ? null : () => Navigator.of(ctx).pop(true),
              child: const Text('Send')),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final title = album.title(kidName);
  try {
    final res = await JamJotBackend.client.functions.invoke('fan-share', body: {
      'student_id': studentId,
      'fan_ids': picked.toList(),
      'album_key': album.key,
      'album_title': title,
      'origin': Uri.base.origin,
      'clips': [
        for (final s in album.songs)
          {
            'title': s.title,
            'first_path': s.first.path,
            'last_path': s.hasFinal ? s.last.path : null
          },
      ],
    });
    final data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
    if (!context.mounted) return;
    if (data['sent'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Sent to ${picked.length} Superfan${picked.length == 1 ? '' : 's'}!')));
      return;
    }
    final links = ((data['links'] as List?) ?? []).cast<Map>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send your album'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Tap a name to email them their private album link.'),
          const SizedBox(height: 8),
          for (final l in links)
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: Text(l['name'] as String),
              onTap: () => sendByEmail(ctx,
                  to: l['email'] as String,
                  subject: '${kidName.split(' ').first} sent you an album',
                  body:
                      'Hi ${l['name']}!\n\n${kidName.split(' ').first} practiced hard and made an album for you: "$title".\n'
                      'Listen to the first and last take of each song, then send some fan mail:\n\n${l['link']}\n'),
            ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done'))
        ],
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not send right now. Please try again.')));
    }
  }
}

/// Fan mail from Superfans. Kids see approved notes; grown-ups see all
/// and can approve or hide (see SuperfansPanel).
class FanMailList extends ConsumerWidget {
  const FanMailList(
      {super.key, required this.studentId, required this.kidView});
  final String studentId;
  final bool kidView;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final mail = (ref.watch(fanMailProvider(studentId)).valueOrNull ?? [])
        .where((m) => !kidView || m['status'] == 'approved')
        .toList();
    if (mail.isEmpty) {
      return ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 12),
        const Center(child: AlienCrowd(width: 260, cheering: false)),
        const SizedBox(height: 8),
        Text('No fan mail yet',
            style: text.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
            'Send an album to your Superfans and their notes will show up here.',
            style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
            textAlign: TextAlign.center),
      ]);
    }
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(fanMailProvider(studentId)),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        for (final m in mail) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: JamJotColors.plumTint,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: JamJotColors.ink, width: 2),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Image.asset('assets/art/notestar/fan_alien.png',
                    width: 30, height: 30, excludeFromSemantics: true),
                const SizedBox(width: 8),
                Expanded(
                    child:
                        Text('From ${m['fan_name']}', style: text.titleMedium)),
                if (!kidView && m['status'] == 'pending')
                  const Chip(label: Text('Waiting for you')),
              ]),
              const SizedBox(height: 6),
              Text(m['message'] as String, style: text.bodyLarge),
              const SizedBox(height: 4),
              Text(
                  '${(m['fan_shares'] as Map?)?['album_title'] ?? ''} · ${DateFormat.MMMd().format(DateTime.parse(m['created_at'] as String).toLocal())}',
                  style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
            ]),
          ),
          const SizedBox(height: 12),
        ],
      ]),
    );
  }
}
