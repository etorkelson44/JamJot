import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/supabase_service.dart';
import '../../theme/jamjot_theme.dart';
import '../library/library_screen.dart' show showCreateLessonDialog;

/// Photo/PDF of a written lesson sheet → a pre-filled lesson draft, matched
/// against the family's library, ready to correct and assign. With [kid] it
/// targets that child; without, it opens the full flow (build the lesson,
/// then optionally pick students, each with their own notes/goals/date).
Future<void> scanSheetToLesson(BuildContext context, WidgetRef ref,
    {Map<String, dynamic>? kid, String? enrollmentId}) async {
  // First: camera, or something already scanned/photographed?
  final how = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Scan a written assignment'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop('camera'),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('📷  Take a photo with the camera'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop('upload'),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('📁  Upload a photo or PDF'),
          ),
        ),
      ],
    ),
  );
  if (how == null || !context.mounted) return;

  Uint8List? bytes;
  String mediaType = 'image/jpeg';
  if (how == 'camera') {
    // On phones and tablets this opens the camera; on a computer without
    // one it falls back to choosing a picture.
    final shot = await ImagePicker().pickImage(
        source: ImageSource.camera, maxWidth: 2200, imageQuality: 88);
    if (shot == null) return;
    bytes = await shot.readAsBytes();
    final n = shot.name.toLowerCase();
    if (n.endsWith('.png')) mediaType = 'image/png';
  } else {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    bytes = file.bytes!;
    final ext = file.extension?.toLowerCase() ?? 'jpg';
    mediaType = switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      _ => 'image/jpeg',
    };
  }
  if (!context.mounted) return;
  if (bytes.length > 15 * 1024 * 1024) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('That file is too big — try a photo instead.')));
    return;
  }

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
        'image_base64': base64Encode(bytes),
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
    var lessons = ((data['lessons'] as List?) ?? [
      if (data['draft'] != null) data['draft'],
    ])
        .map((l) => Map<String, dynamic>.from(l as Map))
        .toList();
    if (lessons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text((data['error'] as String?) ??
              'Could not read that sheet — try a clearer photo?')));
      return;
    }

    // More than one lesson on the sheet? Offer to split.
    if (lessons.length > 1) {
      final split = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('This sheet has ${lessons.length} lessons'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'The scanner found separate lessons on this sheet:'),
              const SizedBox(height: 8),
              for (final l in lessons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('📚 ${l['lesson_title'] ?? 'Lesson'}'),
                ),
              const SizedBox(height: 8),
              const Text(
                  'Save them one at a time, or combine everything into one lesson?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Combine into one'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
              child: Text('Split into ${lessons.length}'),
            ),
          ],
        ),
      );
      if (split == null || !context.mounted) return;
      if (split == false) {
        // Fold everything into one lesson.
        final first = lessons.first;
        final merged = <String, dynamic>{
          'lesson_title': first['lesson_title'] ?? 'This week',
          'lesson_note': lessons
              .map((l) => (l['lesson_note'] as String?) ?? '')
              .where((n) => n.isNotEmpty)
              .join('\n'),
          'goal_days': first['goal_days'],
          'goal_minutes': first['goal_minutes'],
          'assignments': [
            for (final l in lessons) ...((l['assignments'] as List?) ?? []),
          ],
        };
        lessons = [merged];
      }
    }

    // Walk through saving each lesson (usually just one).
    for (var i = 0; i < lessons.length; i++) {
      if (!context.mounted) return;
      if (lessons.length > 1) {
        final go = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Lesson ${i + 1} of ${lessons.length}'),
            content:
                Text('📚 ${lessons[i]['lesson_title'] ?? 'Lesson'}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('stop'),
                child: const Text('Stop here'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('skip'),
                child: const Text('Skip this one'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop('go'),
                style:
                    FilledButton.styleFrom(minimumSize: const Size(96, 44)),
                child: const Text('Review & save'),
              ),
            ],
          ),
        );
        if (go == 'stop' || go == null) return;
        if (go == 'skip') continue;
        if (!context.mounted) return;
      }
      await showCreateLessonDialog(context, ref,
          student: kid, enrollmentId: enrollmentId, draft: lessons[i]);
    }
  } catch (_) {
    if (context.mounted) {
      if (dialogOpen) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Scanning hiccuped — try again, or a clearer photo?')));
    }
  }
}
