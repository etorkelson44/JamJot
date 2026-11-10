import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sound_effects.dart';

/// Presentation only. Server balances remain the authority for all coins.
class CoinRewardTracker {
  String? _studentId;
  int? _balance;

  int observe(String? studentId, int? balance) {
    if (studentId != _studentId) {
      _studentId = studentId;
      _balance = null;
    }
    if (studentId == null || balance == null) return 0;
    final previous = _balance;
    _balance = balance;
    return previous != null && balance > previous ? balance - previous : 0;
  }
}

/// Plays one coin blip per entry, each [delaysMs] milliseconds from now.
final coinSoundPlayerProvider = Provider<void Function(List<int> delaysMs)>(
    (ref) => (delaysMs) => playCoinPings(delaysMs));
