import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/supabase_service.dart';
import '../../theme/jamjot_theme.dart';
import '../library/library_screen.dart' show showCreateLessonDialog;

/// Photo/PDF of a written lesson sheet → a pre-filled lesson draft, matched
/// against the family's library, ready to correct and assign. With [kid] it
/// targets that child; without, it opens the full flow (build the lesson,
/// then optionally pick students, each with their own notes/goals/date).
Future<void> scanSheetToLesson(BuildContext context, WidgetRef ref,
    {Map<String, dynamic>? kid, String? enrollmentId}) async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    withData: true,
  );
  final file = picked?.files.firstOrNull;
  if (file == null || file.bytes == null || !context.mounted) return;
  if (file.bytes!.length > 15 * 1024 * 1024) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('That file is too big — try a photo instead.')));
    return;
  }
  final ext = file.extension?.toLowerCase() ?? 'jpg';
  final mediaType = switch (ext) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    _ => 'image/jpeg',
  };

  // A little patience screen while the sheet is read.
  var dialogOpen = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AlertDialog(
      content: Row(children: [
        CircularProgressIndicator(),
        SizedBox(width: 16),
        Expanded(child: Text('Reading the sheet…\nThis takes ~15 seconds.')),
      ]),
    ),
  ).then((_) => dialogOpen = false);

  try {
    final res = await JamJotBackend.client.functions.invoke(
      'scan-lesson',
      body: {
        'image_base64': base64Encode(file.bytes!),
        'media_type': mediaType,
      },
    );
    if (!context.mounted) return;
    if (dialogOpen) Navigator.of(context, rootNavigator: true).pop();
    final data = res.data as Map<String, dynamic>? ?? {};
    if (data['error'] == 'scan_not_configured') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          duration: Duration(seconds: 6),
          content: Text(
              'The scanner\'s reading brain isn\'t connected yet — it needs an AI key added to the backend. Everything else is ready!')));
      return;
    }
    final draft = data['draft'] as Map<String, dynamic>?;
    if (draft == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text((data['error'] as String?) ??
              'Could not read that sheet — try a clearer photo?')));
      return;
    }
    await showCreateLessonDialog(context, ref,
        student: kid, enrollmentId: enrollmentId, draft: draft);
  } catch (_) {
    if (context.mounted) {
      if (dialogOpen) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Scanning hiccuped — try again, or a clearer photo?')));
    }
  }
}
