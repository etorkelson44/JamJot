import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// Hash used for kid PINs and the grown-up app PIN. Not a password system —
/// real security is the account password; PINs only gate profile switching.
String hashPin(String pin) =>
    sha256.convert(utf8.encode('jamjot:$pin')).toString();

/// The signed-in grown-up's profile row.
final myProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null) return null;
  return JamJotBackend.client
      .from('profiles')
      .select()
      .eq('id', uid)
      .maybeSingle();
});

/// Students this grown-up is a guardian of (with their guardianship row).
final myStudentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null) return [];
  final rows = await JamJotBackend.client
      .from('guardianships')
      .select('is_primary, students(*)')
      .eq('profile_id', uid);
  return [
    for (final r in rows)
      if (r['students'] != null)
        {...(r['students'] as Map<String, dynamic>), 'is_primary': r['is_primary']},
  ];
});

/// This grown-up's teacher row, if they teach.
final myTeacherProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null) return null;
  final rows = await JamJotBackend.client
      .from('teachers')
      .select()
      .eq('profile_id', uid);
  return rows.isEmpty ? null : rows.first as Map<String, dynamic>;
});

/// Who is currently "driving" the app: null = the grown-up, otherwise a
/// student row from myStudentsProvider.
final activeStudentProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

/// A student's berry balance (sum of their ledger).
final berryBalanceProvider =
    FutureProvider.family<int, String>((ref, studentId) async {
  final rows = await JamJotBackend.client
      .from('berry_ledger')
      .select('amount')
      .eq('student_id', studentId);
  var total = 0;
  for (final r in rows) {
    total += (r['amount'] as num).toInt();
  }
  return total;
});

/// Remember the active kid across app restarts (best effort).
Future<void> rememberActiveStudent(String? studentId) async {
  final uid = JamJotBackend.client.auth.currentUser?.id;
  if (uid == null) return;
  try {
    await JamJotBackend.client
        .from('profiles')
        .update({'last_active_student': studentId}).eq('id', uid);
  } catch (_) {/* non-fatal */}
}
