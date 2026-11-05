import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../services/session_flags.dart';
import '../../widgets/maestro_loader.dart';

/// Decides where a freshly signed-in person goes: onboarding if their
/// account is brand new, otherwise the profile picker.
class GateScreen extends ConsumerStatefulWidget {
  const GateScreen({super.key});

  @override
  ConsumerState<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends ConsumerState<GateScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    // Fresh reads every time we pass through the gate.
    ref.invalidate(myProfileProvider);
    ref.invalidate(myStudentsProvider);
    ref.invalidate(myTeacherProvider);
    final students = await ref.read(myStudentsProvider.future);
    final teacher = await ref.read(myTeacherProvider.future);
    if (!mounted) return;
    // An invite link is waiting? Finish that connection first.
    if (pendingInviteToken != null) {
      context.go('/invite?token=$pendingInviteToken');
      return;
    }
    if (students.isEmpty && teacher == null) {
      // Brand-new account: honor the role they picked on the landing page.
      final intended = JamJotBackend
          .client.auth.currentUser?.userMetadata?['intended_role'];
      if (intended == 'family') {
        context.go('/add-student');
      } else if (intended == 'teacher') {
        context.go('/teacher-setup');
      } else {
        context.go('/onboarding');
      }
    } else {
      // A refresh mid-session shouldn't dump anyone back on the profile
      // picker: restore the same profile AND the same page if this tab
      // was active recently.
      final storedId = freshActiveStudent(kidSessionIdle);
      final target = bootTarget;
      bootTarget = null;
      if (storedId == grownUpSession) {
        touchActiveSession();
        context.go(target ?? '/home');
        return;
      }
      if (storedId != null) {
        Map<String, dynamic>? kid;
        for (final s in students) {
          if (s['id'] == storedId) kid = s;
        }
        if (kid != null) {
          ref.read(activeStudentProvider.notifier).state = kid;
          touchActiveSession();
          context.go(target ?? '/home');
          return;
        }
      }
      context.go('/profiles');
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: MaestroLoader()));
}
