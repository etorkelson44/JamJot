import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

final coinSoundPlayerProvider =
    Provider<void Function()>((ref) => () => playSound('coinDrop'));

final coinSoundsProvider =
    StateNotifierProvider<CoinSounds, bool>((ref) => CoinSounds());

class CoinSounds extends StateNotifier<bool> {
  CoinSounds() : super(true) {
    _load();
  }
  static const preferenceKey = 'jamjot.coin_sounds';
  bool _changed = false;
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted && !_changed) state = prefs.getBool(preferenceKey) ?? true;
    } catch (_) {/* Optional preference must never block the app. */}
  }

  Future<void> setEnabled(bool enabled) async {
    _changed = true;
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(preferenceKey, enabled);
    } catch (_) {/* The current session still respects the choice. */}
  }
}
