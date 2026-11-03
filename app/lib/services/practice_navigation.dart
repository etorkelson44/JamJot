import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The active practice screen owns the decision; the tab bar awaits it.
class PracticeExitGuard {
  Future<bool> Function()? beforeLeave;
}

final practiceExitGuardProvider = Provider((ref) => PracticeExitGuard());
