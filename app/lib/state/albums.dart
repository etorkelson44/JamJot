import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// NoteStar weekly albums (Erika, 2026-11-15).
/// One album per lesson week. A week ends at the teacher's finalize time on
/// the evening before the lesson (the same moment the lesson sheet locks).
/// Each song gets its first take and its last take of that week; a kid can
/// swap the last take for another take they like better (album_picks).
/// Takes under one minute of real sound don't count (the practice rule).
class AlbumTake {
  AlbumTake(this.path, this.at, this.soundSeconds);
  final String path;
  final DateTime at;
  final int soundSeconds;
}

class AlbumSong {
  AlbumSong(this.assignmentId, this.title, this.takes, this.pickedPath);
  final String assignmentId;
  final String title;
  final List<AlbumTake> takes; // oldest first
  final String? pickedPath;
  AlbumTake get first => takes.first;
  bool get hasFinal => takes.length > 1;
  AlbumTake get last {
    if (pickedPath != null) {
      final p = takes.where((t) => t.path == pickedPath && t != takes.first);
      if (p.isNotEmpty) return p.first;
    }
    return takes.last;
  }
}

class Album {
  Album(this.key, this.volume, this.from, this.to, this.songs);
  final String key; // the cutoff time (UTC ISO)
  final int volume;
  final DateTime from;
  final DateTime to;
  final List<AlbumSong> songs;
  String title(String kidName) =>
      "${kidName.split(' ').first}'s Album, Volume ${_roman(volume)}";
}

String _roman(int n) {
  const v = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
  const s = ['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];
  final b = StringBuffer();
  for (var i = 0; i < v.length; i++) {
    while (n >= v[i]) {
      b.write(s[i]);
      n -= v[i];
    }
  }
  return b.toString();
}

const minAlbumSeconds = 60;

class AlbumShelf {
  AlbumShelf(this.albums, this.nextCutoff, this.inProgressSongs);
  final List<Album> albums; // newest first
  final DateTime? nextCutoff; // when this week's album will be made
  final int inProgressSongs; // songs recorded so far this week
}

final albumShelfProvider =
    FutureProvider.autoDispose.family<AlbumShelf, String>((ref, studentId) async {
  final db = JamJotBackend.client;
  final now = DateTime.now();
  // 1) Every take with audio.
  final segs = await db
      .from('session_segments')
      .select(
          'assignment_id, audio_clips, assignments(title), sessions!inner(student_id, started_at)')
      .eq('sessions.student_id', studentId)
      .not('assignment_id', 'is', null);
  final takesBySong = <String, List<AlbumTake>>{};
  final titles = <String, String>{};
  for (final s in segs) {
    final aid = s['assignment_id'] as String?;
    if (aid == null) continue;
    titles[aid] = ((s['assignments'] as Map?)?['title'] as String?) ?? 'Song';
    final started = DateTime.tryParse(
        ((s['sessions'] as Map?)?['started_at'] as String?) ?? '');
    for (final c in ((s['audio_clips'] as List?) ?? []).cast<Map>()) {
      final secs = (c['sound_seconds'] as num?)?.toInt() ?? 0;
      final path = c['path'] as String?;
      if (path == null || secs < minAlbumSeconds) continue;
      final at = DateTime.tryParse((c['at'] as String?) ?? '')?.toLocal() ??
          started?.toLocal();
      if (at == null) continue;
      (takesBySong[aid] ??= []).add(AlbumTake(path, at, secs));
    }
  }
  // 2) Week ends: the evening before each lesson at the finalize hour.
  final cutoffs = <DateTime>[];
  try {
    final ev = await db
        .from('event_students')
        .select('calendar_events(kind, starts_at, teachers(finalize_hour))')
        .eq('student_id', studentId);
    for (final r in ev) {
      final e = r['calendar_events'] as Map?;
      if (e == null || e['kind'] != 'lesson') continue;
      final starts = DateTime.parse(e['starts_at'] as String).toLocal();
      final fh = ((e['teachers'] as Map?)?['finalize_hour'] as num?)?.toInt() ?? 21;
      final day = DateTime(starts.year, starts.month, starts.day)
          .subtract(const Duration(days: 1));
      cutoffs.add(DateTime(day.year, day.month, day.day, fh));
    }
  } catch (_) {/* no calendar: fall back to weekly */}
  final allTakes = takesBySong.values.expand((e) => e).toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  if (cutoffs.isEmpty && allTakes.isNotEmpty) {
    // No lessons on the calendar: weeks end Sunday at 9 PM.
    var d = allTakes.first.at;
    var sunday = DateTime(d.year, d.month, d.day + (7 - d.weekday) % 7, 21);
    if (!sunday.isAfter(d)) sunday = sunday.add(const Duration(days: 7));
    while (sunday.isBefore(now.add(const Duration(days: 8)))) {
      cutoffs.add(sunday);
      sunday = sunday.add(const Duration(days: 7));
    }
  }
  cutoffs.sort();
  final uniq = <DateTime>[];
  for (final c in cutoffs) {
    if (uniq.isEmpty || c.difference(uniq.last).inHours.abs() > 12) uniq.add(c);
  }
  // 3) Saved "swap take" choices.
  final picks = <String, String>{};
  try {
    final rows = await db
        .from('album_picks')
        .select('album_key, assignment_id, clip_path')
        .eq('student_id', studentId);
    for (final r in rows) {
      picks['${r['album_key']}/${r['assignment_id']}'] = r['clip_path'] as String;
    }
  } catch (_) {}
  // 4) Build the finished albums.
  final albums = <Album>[];
  DateTime? prev;
  DateTime? next;
  var vol = 0;
  for (final c in uniq) {
    if (c.isAfter(now)) {
      next ??= c;
      continue;
    }
    final from = prev ?? c.subtract(const Duration(days: 7));
    final key = c.toUtc().toIso8601String();
    final songs = <AlbumSong>[];
    takesBySong.forEach((aid, takes) {
      final inWeek = takes
          .where((t) => t.at.isAfter(from) && !t.at.isAfter(c))
          .toList()
        ..sort((a, b) => a.at.compareTo(b.at));
      if (inWeek.isEmpty) return;
      songs.add(AlbumSong(aid, titles[aid] ?? 'Song', inWeek, picks['$key/$aid']));
    });
    prev = c;
    if (songs.isEmpty) continue;
    songs.sort((a, b) => a.first.at.compareTo(b.first.at));
    vol++;
    albums.add(Album(key, vol, from, c, songs));
  }
  final since = prev ?? now.subtract(const Duration(days: 7));
  final inProgress = takesBySong.values
      .where((t) => t.any((x) => x.at.isAfter(since)))
      .length;
  return AlbumShelf(albums.reversed.toList(), next, inProgress);
});

/// Save "use this take as my last take" for one song in one album.
Future<void> pickAlbumTake(String studentId, String albumKey,
    String assignmentId, String path) async {
  await JamJotBackend.client.from('album_picks').upsert({
    'student_id': studentId,
    'album_key': albumKey,
    'assignment_id': assignmentId,
    'clip_path': path,
  }, onConflict: 'student_id,album_key,assignment_id');
}

/// Superfans (family members a grown-up added) for a kid.
final superfansProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, studentId) async {
  final rows = await JamJotBackend.client
      .from('fans')
      .select('id, name, email, created_at')
      .eq('student_id', studentId)
      .order('created_at');
  return rows.cast<Map<String, dynamic>>();
});

/// Fan mail for a kid. Grown-ups see every note; kids only approved ones.
final fanMailProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, studentId) async {
  final rows = await JamJotBackend.client
      .from('fan_mail')
      .select('id, fan_name, message, status, created_at, fan_shares(album_title)')
      .eq('student_id', studentId)
      .order('created_at', ascending: false)
      .limit(100);
  return rows.cast<Map<String, dynamic>>();
});
