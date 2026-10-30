import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_service.dart';
import '../../state/app_state.dart';

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
      context.go('/profiles');
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
