/// The instrument list (JJ-036-C): names, picture files, nicknames, and the
/// on-device search used by the instrument picker.
///
/// Saved values are never rewritten. Old saved names ("Guitar") and typed-in
/// instruments still work: [resolveInstrument] maps any saved text to the
/// closest list entry for its picture, or to [otherInstrument].
library;

class Instrument {
  const Instrument(this.key, this.name, [this.nicknames = const []]);

  /// File-safe key: `assets/instruments/<key>.webp` and the avatar stills
  /// lookup (`assets/art/avatar_instrument/<avatar>_<key>.png`).
  final String key;

  /// What kids see and what gets saved.
  final String name;

  /// Extra words a kid might type for this instrument.
  final List<String> nicknames;

  String get asset => 'assets/instruments/$key.webp';
}

const _drums = ['drums', 'percussion'];

const kInstrumentCatalog = <Instrument>[
  Instrument('piano', 'Piano', ['keys', 'keyboard']),
  Instrument('violin', 'Violin', ['fiddle']),
  Instrument('viola', 'Viola'),
  Instrument('cello', 'Cello', ['violoncello']),
  Instrument('double_bass', 'Double bass',
      ['bass', 'upright bass', 'string bass', 'contrabass']),
  Instrument('acoustic_guitar', 'Acoustic guitar', ['guitar']),
  Instrument('electric_guitar', 'Electric guitar', ['guitar']),
  Instrument('bass_guitar', 'Bass guitar', ['guitar', 'bass', 'electric bass']),
  Instrument('ukulele', 'Ukulele', ['uke']),
  Instrument('harp', 'Harp'),
  Instrument('voice', 'Voice', ['singing', 'vocals', 'singer', 'choir']),
  Instrument('flute', 'Flute'),
  Instrument('piccolo', 'Piccolo'),
  Instrument('oboe', 'Oboe'),
  Instrument('clarinet', 'Clarinet'),
  Instrument('bass_clarinet', 'Bass clarinet', ['bass']),
  Instrument('bassoon', 'Bassoon'),
  Instrument('saxophone', 'Saxophone', ['sax', 'alto sax', 'tenor sax']),
  Instrument('trumpet', 'Trumpet'),
  Instrument('french_horn', 'French horn', ['horn']),
  Instrument('trombone', 'Trombone'),
  Instrument('euphonium', 'Euphonium', ['baritone']),
  Instrument('tuba', 'Tuba'),
  Instrument('sousaphone', 'Sousaphone'),
  Instrument('mellophone', 'Mellophone', ['horn']),
  Instrument('drums', 'Drums', ['drum set', 'drum kit', 'percussion']),
  Instrument('snare_drum', 'Snare drum', _drums),
  Instrument('tenor_drums', 'Tenor drums', ['quads', 'quints', ..._drums]),
  Instrument('bass_drum', 'Bass drum', ['bass', ..._drums]),
  Instrument('cymbals', 'Cymbals', _drums),
  Instrument('timpani', 'Timpani', ['kettle drums', ..._drums]),
  Instrument('mallet_percussion', 'Mallet percussion', [
    'mallets', 'marimba', 'xylophone', 'vibraphone', 'glockenspiel',
    'bells', ..._drums
  ]),
  Instrument('harmonica', 'Harmonica'),
  Instrument('accordion', 'Accordion'),
];

/// The music-notes picture for anything not on the list.
const otherInstrument = Instrument('other', 'Other');

/// Lowercase, punctuation to spaces, single spaces.
String normalizeInstrument(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9\s]"), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

List<String> _words(String s) =>
    normalizeInstrument(s).split(' ').where((w) => w.isNotEmpty).toList();

/// Exact saved values from before the list existed, plus common spellings.
const _legacy = <String, String>{
  'guitar': 'acoustic_guitar',
  'keyboard': 'piano',
  'drum': 'drums',
  'drumset': 'drums',
  'sax': 'saxophone',
  'uke': 'ukulele',
  'bass': 'bass_guitar',
  'horn': 'french_horn',
  'singing': 'voice',
  'vocals': 'voice',
  'percussion': 'drums',
};

/// The list entry whose picture goes with a saved instrument value;
/// [otherInstrument] when nothing matches.
Instrument resolveInstrument(String? saved) {
  if (saved == null) return otherInstrument;
  final n = normalizeInstrument(saved);
  if (n.isEmpty) return otherInstrument;
  for (final i in kInstrumentCatalog) {
    if (normalizeInstrument(i.name) == n || i.key.replaceAll('_', ' ') == n) {
      return i;
    }
  }
  final legacy = _legacy[n] ?? _legacy[n.replaceAll(' ', '')];
  if (legacy != null) return byInstrumentKey(legacy)!;
  for (final i in kInstrumentCatalog) {
    if (i.nicknames.any((nick) => normalizeInstrument(nick) == n) &&
        !_sharedNickname(n)) {
      return i;
    }
  }
  return otherInstrument;
}

bool _sharedNickname(String n) =>
    kInstrumentCatalog.where((i) => i.nicknames.contains(n)).length > 1;

Instrument? byInstrumentKey(String key) {
  for (final i in kInstrumentCatalog) {
    if (i.key == key) return i;
  }
  return null;
}

/// Does every typed word match the start of a word in [alias]?
bool _aliasMatches(List<String> query, String alias) {
  final words = _words(alias);
  return query.every((q) => words.any((w) => w.startsWith(q)));
}

/// All instruments matching what was typed (no cap), list order, with
/// name matches ahead of nickname-only matches.
List<Instrument> searchInstruments(String typed) {
  final q = _words(typed);
  if (q.isEmpty) return const [];
  final byName = <Instrument>[];
  final byNick = <Instrument>[];
  for (final i in kInstrumentCatalog) {
    if (_aliasMatches(q, i.name)) {
      byName.add(i);
    } else if (i.nicknames.any((n) => _aliasMatches(q, n))) {
      byNick.add(i);
    }
  }
  return [...byName, ...byNick];
}

int _editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost]
          .reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Up to 3 close spellings when nothing matches ("Did you mean…?").
List<Instrument> didYouMean(String typed) {
  final q = normalizeInstrument(typed);
  if (q.length < 3) return const [];
  final qNoSpace = q.replaceAll(' ', '');
  final limit = q.length <= 5 ? 1 : (q.length <= 8 ? 2 : 3);
  final scored = <(Instrument, int)>[];
  for (final i in kInstrumentCatalog) {
    var best = 1 << 20;
    for (final alias in [i.name, ...i.nicknames]) {
      final a = normalizeInstrument(alias);
      final candidates = {a, a.replaceAll(' ', ''), ..._words(a)};
      for (final c in candidates) {
        // Compare against the whole alias and against its start, so a
        // half-typed misspelling ("clarnet", "trumpit") still finds it.
        final whole = _editDistance(qNoSpace, c.replaceAll(' ', ''));
        final head = c.length > q.length
            ? _editDistance(qNoSpace, c.substring(0, q.length))
            : whole;
        final d = whole < head ? whole : head;
        if (d < best) best = d;
      }
    }
    if (best <= limit) scored.add((i, best));
  }
  scored.sort((a, b) => a.$2.compareTo(b.$2));
  return scored.take(3).map((e) => e.$1).toList();
}

/// Tidy a typed instrument: strip extra spaces and symbols, lowercase,
/// capitalize the first letter. Empty when nothing usable is left.
String tidyInstrumentName(String typed) {
  final cleaned = typed
      .replaceAll(RegExp(r"[^A-Za-z\s'\-]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
  if (cleaned.isEmpty) return '';
  final s = cleaned.length > 40 ? cleaned.substring(0, 40).trim() : cleaned;
  return s[0].toUpperCase() + s.substring(1);
}

// A small on-device list; it never leaves the device.
const _blockedWords = {
  'ass', 'asshole', 'bastard', 'bitch', 'bollocks', 'butt', 'butthole',
  'crap', 'cock', 'cunt', 'damn', 'dick', 'dildo', 'fag', 'faggot', 'fart',
  'fuck', 'fucker', 'fucking', 'hell', 'jerk', 'nazi', 'nigga', 'nigger',
  'penis', 'piss', 'poop', 'porn', 'pussy', 'retard', 'sex', 'sexy', 'shit',
  'slut', 'stupid', 'tits', 'twat', 'vagina', 'wanker', 'whore', 'idiot',
  'dumb', 'kill', 'die', 'hate', 'boob', 'boobs',
};

// Blocked even inside another word ("xfuckx").
const _blockedParts = {'fuck', 'shit', 'cunt', 'nigg', 'fagg', 'whore', 'porn'};

// Common first names, to keep kids from typing their own or a friend's name.
const _commonNames = {
  'aaron', 'abigail', 'adam', 'aiden', 'alex', 'alexander', 'alice', 'amelia',
  'amy', 'andrew', 'anna', 'ava', 'ben', 'benjamin', 'caleb', 'charlie',
  'charlotte', 'chloe', 'chris', 'daniel', 'david', 'dylan', 'eli', 'elijah',
  'ella', 'emily', 'emma', 'ethan', 'evelyn', 'grace', 'hannah', 'harper',
  'henry', 'isaac', 'isabella', 'jack', 'jacob', 'james', 'jayden', 'jessica',
  'john', 'jose', 'joseph', 'joshua', 'julia', 'kate', 'katie', 'leah', 'leo',
  'liam', 'lily', 'logan', 'lucas', 'lucy', 'luke', 'madison', 'maria',
  'mason', 'matthew', 'max', 'mia', 'michael', 'mila', 'noah', 'nora',
  'oliver', 'olivia', 'owen', 'ryan', 'samuel', 'sarah', 'scarlett', 'sofia',
  'sophia', 'sophie', 'thomas', 'tyler', 'william', 'zoe', 'erika',
};

/// Why a typed instrument can't be added, or null when it's fine.
/// Checks run on the device only.
String? instrumentInputProblem(String typed) {
  final raw = typed.trim();
  final lower = raw.toLowerCase();
  if (raw.isEmpty) return 'Type an instrument name first.';
  if (RegExp(r'[0-9]').hasMatch(raw)) {
    return 'Instrument names can\'t have numbers. Try just the name.';
  }
  if (raw.contains('@') ||
      RegExp(r'(https?:|www\.|\.com|\.net|\.org)').hasMatch(lower)) {
    return 'That looks like an email or a web address. Try just the instrument name.';
  }
  final words = _words(raw);
  if (words.any(_blockedWords.contains) ||
      _blockedParts.any(lower.replaceAll(' ', '').contains)) {
    return 'Let\'s pick a different word for that one.';
  }
  if (RegExp(r"\b(my name|i am|i'm|im called)\b").hasMatch(lower) ||
      words.any(_commonNames.contains)) {
    return 'That looks like a person\'s name. Type the instrument instead.';
  }
  if (tidyInstrumentName(raw).length < 2) {
    return 'Type an instrument name first.';
  }
  return null;
}
