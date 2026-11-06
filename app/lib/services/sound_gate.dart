/// The caregiver's choice of which sound effects a student's profile plays.
///
/// Stored on the student row as `sound_prefs` (see the
/// 20261106140000_student_sound_prefs migration). A missing key means "on",
/// so profiles that were never touched behave exactly as before.
class SoundEffectOption {
  const SoundEffectOption(this.key, this.title, this.subtitle);
  final String key;
  final String title;
  final String subtitle;
}

/// Every sound effect JamJot can play, in the order shown to caregivers.
/// The keys match the names passed to playSound / playCoinPings.
const soundEffectOptions = <SoundEffectOption>[
  SoundEffectOption(
      'coins', 'Coin jingle', 'Plays as coins drop into the Jam Jar.'),
  SoundEffectOption(
      'cheer', 'Crowd cheer', 'When a song is finished and fans cheer.'),
  SoundEffectOption(
      'fanfare', 'Practice fanfare', 'A short tune when a practice wraps up.'),
  SoundEffectOption(
      'pop', 'Market pop', 'A little pop after buying something.'),
];

class SoundGate {
  Map<String, dynamic> _prefs = const {};

  /// Called with the active student's `sound_prefs` (null for the grown-up
  /// view or a profile that has never set anything).
  void apply(Object? prefs) {
    _prefs = prefs is Map ? Map<String, dynamic>.from(prefs) : const {};
  }

  bool get masterOn => _prefs['enabled'] != false;

  bool allows(String effect) {
    if (!masterOn) return false;
    // The synthesized 'coin' blip belongs to the coin jingle setting.
    final key = effect == 'coin' ? 'coins' : effect;
    return _prefs[key] != false;
  }
}

/// The one gate every sound effect asks before playing.
final soundGate = SoundGate();
