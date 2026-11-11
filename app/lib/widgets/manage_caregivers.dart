import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;
import '../services/supabase_service.dart';
import '../theme/jamjot_theme.dart';

/// Result of cancelling an invite or removing a caregiver (JJ-056-C, JJ-057-C).
class ManageCaregiversResult {
  const ManageCaregiversResult({this.error, this.notified = false});
  final String? error;
  final bool notified;
}

/// Calls the manage-caregivers edge function. The server checks that only the
/// primary caregiver can do this, and sends the notice email.
Future<ManageCaregiversResult> manageCaregivers(
    Map<String, dynamic> body) async {
  try {
    final res = await JamJotBackend.client.functions
        .invoke('manage-caregivers', body: body);
    final data = res.data as Map<String, dynamic>? ?? {};
    return ManageCaregiversResult(notified: data['notified'] == true);
  } on FunctionException catch (e) {
    final d = e.details;
    final msg = d is Map ? d['error'] as String? : null;
    return ManageCaregiversResult(error: msg ?? 'That did not work just now.');
  } catch (_) {
    return const ManageCaregiversResult(
        error: 'That did not work. Please check your connection and try again.');
  }
}

/// A plain "are you sure" window (no PIN needed).
Future<bool?> confirmCaregiverAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
}) =>
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
