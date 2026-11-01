import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:url_launcher/url_launcher.dart';

import '../../services/folder_picker.dart';
import '../../services/unload_guard.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/jamjot_theme.dart';

/// My Library: Files (music/books), Assignments, and Lessons — with loose
/// search everywhere. Later, score stores & converters plug in here too.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Library'),
          leading: BackButton(onPressed: () => context.go('/home')),
          bottom: const TabBar(tabs: [
            Tab(text: 'Files'),
            Tab(text: 'Assignments'),
            Tab(text: 'Lessons'),
          ]),
        ),
        body: const TabBarView(children: [
          _FilesTab(),
          _AssignmentsTab(),
          _LessonsTab(),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- helpers

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

Future<void> _openScoreFile(BuildContext context, String path) async {
  try {
    final url = await JamJotBackend.client.storage
        .from('scores')
        .createSignedUrl(path, 3600);
    await launchUrl(Uri.parse(url));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open that file.')));
    }
  }
}

/// Saves one file's bytes into the library, under [folder].
Future<Map<String, dynamic>?> _saveScoreBytes(
  WidgetRef ref, {
  required String fileName,
  required List<int> bytes,
  String folder = '',
}) async {
  final uid = JamJotBackend.client.auth.currentUser!.id;
  final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final path = '$uid/${DateTime.now().microsecondsSinceEpoch}-$safeName';
  await JamJotBackend.client.storage
      .from('scores')
      .uploadBinary(path, Uint8List.fromList(bytes),
          fileOptions: const FileOptions())
      .timeout(const Duration(seconds: 60));
  final title = fileName.contains('.')
      ? fileName.substring(0, fileName.lastIndexOf('.'))
      : fileName;
  final row = await JamJotBackend.client
      .from('scores')
      .insert({
        'owner_id': uid,
        'title': title,
        'original_path': path,
        'folder': folder,
        'meta': {'file_name': fileName, 'size': bytes.length},
      })
      .select()
      .single();
  return row;
}

/// Picks ONE file (used when attaching to an assignment).
Future<Map<String, dynamic>?> uploadScoreFile(
    BuildContext context, WidgetRef ref, {String folder = ''}) async {
  final picked = await FilePicker.platform
      .pickFiles(type: FileType.custom, allowedExtensions: [
    'pdf', 'png', 'jpg', 'jpeg', 'xml', 'musicxml', 'mxl'
  ], withData: true);
  final file = picked?.files.firstOrNull;
  if (file == null || file.bytes == null) return null;
  try {
    final row = await _saveScoreBytes(ref,
        fileName: file.name, bytes: file.bytes!, folder: folder);
    ref.invalidate(libraryScoresProvider);
    return row;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed — please try again.')));
    }
    return null;
  }
}

/// Picks MANY files at once into [folder] (shift/cmd-click to select
/// several). Returns the finished-message to show.
Future<String> uploadScoreFiles(BuildContext context, WidgetRef ref,
    {String folder = '',
    void Function(String status)? onProgress}) async {
  final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'png', 'jpg', 'jpeg', 'xml', 'musicxml', 'mxl'
      ],
      withData: true);
  final files = picked?.files ?? [];
  if (files.isEmpty) return 'Nothing was selected.';
  setUnloadGuard(true);
  var added = 0;
  var skipped = 0;
  String? firstError;
  try {
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      onProgress?.call('Uploading ${i + 1} of ${files.length} — ${f.name}…');
      if (f.bytes == null) {
        skipped++;
        continue;
      }
      try {
        await _saveScoreBytes(ref,
            fileName: f.name, bytes: f.bytes!, folder: folder);
        added++;
      } catch (e) {
        skipped++;
        firstError ??= e.toString();
      }
    }
  } finally {
    setUnloadGuard(false);
  }
  if (added > 0) ref.invalidate(libraryScoresProvider);
  if (skipped == 0) {
    return '$added file${added == 1 ? '' : 's'} added! 🎉';
  }
  return '$added added • $skipped failed.'
      '${firstError == null ? '' : ' First error: $firstError'}';
}

/// Picks a whole FOLDER; every file keeps its place inside it, so the
/// library mirrors the computer's organization under [folder].
Future<String> uploadScoreFolder(BuildContext context, WidgetRef ref,
    {String folder = '',
    void Function(String status)? onProgress}) async {
  final handles = await pickFolderFiles();
  if (handles.isEmpty) return 'No usable music files found in that folder.';
  setUnloadGuard(true);
  var added = 0;
  var skipped = 0;
  String? firstError;
  try {
  for (var i = 0; i < handles.length; i++) {
    final h = handles[i];
    onProgress?.call(
        'Uploading ${i + 1} of ${handles.length} — ${h.name}…');
    // Reading triggers iCloud to download the file if it isn't local yet.
    final bytes = await h.read();
    if (bytes == null || bytes.isEmpty) {
      skipped++;
      continue;
    }
    final rel = h.relativePath;
    final slash = rel.lastIndexOf('/');
    final sub = slash <= 0 ? '' : rel.substring(0, slash);
    final target = [
      if (folder.isNotEmpty) folder,
      if (sub.isNotEmpty) sub,
    ].join('/');
    try {
      await _saveScoreBytes(ref,
          fileName: h.name, bytes: bytes, folder: target);
      added++;
    } catch (e) {
      skipped++;
      firstError ??= e.toString();
    }
  }
  } finally {
    setUnloadGuard(false);
  }
  if (added > 0) ref.invalidate(libraryScoresProvider);
  if (skipped == 0) {
    return '$added file${added == 1 ? '' : 's'} added! 🎉';
  }
  return '$added added • $skipped skipped'
      '${firstError != null ? ' — first error: $firstError' : ' (could not be read — if they live in iCloud, open the folder in Finder and choose "Download Now", then try those again).'}';
}

class _FilesTab extends ConsumerStatefulWidget {
  const _FilesTab();
  @override
  ConsumerState<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends ConsumerState<_FilesTab> {
  String _query = '';

  /// The folder being looked at ('' = the top of the library).
  String _path = '';

  /// Freshly made folders that have no files yet (so they still show).
  final Set<String> _emptyFolders = {};

  List<String> get _crumbs => _path.isEmpty ? [] : _path.split('/');

  /// Live text shown in the banner while an upload runs.
  String? _progress;

  Future<void> _busyAction(Future<int> Function() run, String what) async {
    setState(() => _progress = 'Reading $what…');
    final count = await run();
    if (!mounted) return;
    setState(() => _progress = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(count == 0
            ? 'No usable music files found to upload.'
            : '$count file${count == 1 ? '' : 's'} added! 🎉')));
  }

  Future<String?> _askName(String title, {String initial = ''}) async {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(c.text.trim()),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(Map<String, dynamic> f) async {
    final name =
        await _askName('Rename file', initial: f['title'] as String? ?? '');
    if (name == null || name.isEmpty) return;
    await JamJotBackend.client
        .from('scores')
        .update({'title': name}).eq('id', f['id']);
    ref.invalidate(libraryScoresProvider);
  }

  Future<void> _move(
      Map<String, dynamic> f, List<Map<String, dynamic>> all) async {
    final folders = <String>{''};
    for (final x in all) {
      final fo = (x['folder'] as String?) ?? '';
      if (fo.isEmpty) continue;
      final parts = fo.split('/');
      for (var i = 1; i <= parts.length; i++) {
        folders.add(parts.sublist(0, i).join('/'));
      }
    }
    folders.addAll(_emptyFolders);
    final sorted = folders.toList()..sort();
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: const Text('Move to…'),
        children: [
          for (final fo in sorted)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(fo),
              child: Text(fo.isEmpty ? '🏠 Top of library' : '📁 $fo'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('::new::'),
            child: const Text('➕ New folder…'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    var target = choice;
    if (choice == '::new::') {
      final name = await _askName('New folder name');
      if (name == null || name.isEmpty) return;
      target = _path.isEmpty ? name : '$_path/$name';
    }
    await JamJotBackend.client
        .from('scores')
        .update({'folder': target}).eq('id', f['id']);
    ref.invalidate(libraryScoresProvider);
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep it')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: JamJotColors.recording,
                minimumSize: const Size(96, 44)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteFile(Map<String, dynamic> f) async {
    final ok = await _confirm('Delete "${f['title']}"?',
        'It disappears from your library. Assignments that pointed to it lose their sheet music.');
    if (!ok) return;
    try {
      final path = f['original_path'] as String?;
      if (path != null) {
        try {
          await JamJotBackend.client.storage.from('scores').remove([path]);
        } catch (_) {}
      }
      await JamJotBackend.client.from('scores').delete().eq('id', f['id']);
      ref.invalidate(libraryScoresProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not delete just now — try again?')));
      }
    }
  }

  Future<void> _deleteFolder(
      String folderPath, List<Map<String, dynamic>> all) async {
    final inside = [
      for (final f in all)
        if ((f['folder'] as String? ?? '') == folderPath ||
            (f['folder'] as String? ?? '').startsWith('$folderPath/'))
          f,
    ];
    final ok = await _confirm(
        'Delete the folder "${folderPath.split('/').last}"?',
        inside.isEmpty
            ? 'The empty folder will be removed.'
            : 'Its ${inside.length} file${inside.length == 1 ? '' : 's'} (including subfolders) will be deleted too.');
    if (!ok) return;
    try {
      final paths = [
        for (final f in inside)
          if (f['original_path'] != null) f['original_path'] as String,
      ];
      if (paths.isNotEmpty) {
        try {
          await JamJotBackend.client.storage.from('scores').remove(paths);
        } catch (_) {}
      }
      for (final f in inside) {
        await JamJotBackend.client.from('scores').delete().eq('id', f['id']);
      }
      setState(() {
        _emptyFolders
            .removeWhere((e) => e == folderPath || e.startsWith('$folderPath/'));
        if (_path == folderPath || _path.startsWith('$folderPath/')) {
          _path = folderPath.contains('/')
              ? folderPath.substring(0, folderPath.lastIndexOf('/'))
              : '';
        }
      });
      ref.invalidate(libraryScoresProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not delete just now — try again?')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(libraryScoresProvider).valueOrNull ?? [];
    final text = Theme.of(context).textTheme;
    final searching = _query.trim().isNotEmpty;

    // What lives right here, and which subfolders open from here.
    final here = <Map<String, dynamic>>[];
    final subfolders = <String, int>{};
    for (final f in files) {
      final fo = (f['folder'] as String?) ?? '';
      if (searching) {
        if (looseMatch(_query, '${f['title'] ?? ''} $fo')) here.add(f);
        continue;
      }
      if (fo == _path) {
        here.add(f);
      } else if (_path.isEmpty
          ? fo.isNotEmpty
          : fo.startsWith('$_path/')) {
        final rest = _path.isEmpty ? fo : fo.substring(_path.length + 1);
        final next = rest.split('/').first;
        subfolders[next] = (subfolders[next] ?? 0) + 1;
      }
    }
    if (!searching) {
      for (final e in _emptyFolders) {
        if (_path.isEmpty ? !e.contains('/') : (e.startsWith('$_path/') && !e.substring(_path.length + 1).contains('/'))) {
          final name = _path.isEmpty ? e : e.substring(_path.length + 1);
          subfolders.putIfAbsent(name, () => 0);
        }
      }
    }
    final folderNames = subfolders.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SearchField(
            hint: 'Search all music & books…',
            onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 12),
        if (_progress != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: JamJotColors.blueberryTint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: JamJotColors.ink, width: 2),
            ),
            child: Row(children: [
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Expanded(child: Text(_progress!)),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        if (!searching) ...[
          // Breadcrumbs.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () => setState(() => _path = ''),
                child: const Text('🏠 Library'),
              ),
              for (var i = 0; i < _crumbs.length; i++) ...[
                const Text('›'),
                TextButton(
                  onPressed: () => setState(
                      () => _path = _crumbs.sublist(0, i + 1).join('/')),
                  child: Text(_crumbs[i]),
                ),
              ],
            ],
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: () async {
                setState(() => _progress = 'Choosing files…');
                final message = await uploadScoreFiles(context, ref,
                    folder: _path,
                    onProgress: (st) {
                      if (mounted) setState(() => _progress = st);
                    });
                if (!mounted) return;
                setState(() => _progress = null);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(message)));
              },
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Upload files (pick several!)'),
            ),
            if (folderPickingSupported)
              FilledButton.icon(
                onPressed: () async {
                  setState(() => _progress = 'Choosing folder…');
                  final message = await uploadScoreFolder(context, ref,
                      folder: _path,
                      onProgress: (st) {
                        if (mounted) setState(() => _progress = st);
                      });
                  if (!mounted) return;
                  setState(() => _progress = null);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(message)));
                },
                icon: const Icon(Icons.drive_folder_upload, size: 18),
                label: const Text('Upload a folder'),
              ),
            OutlinedButton.icon(
              onPressed: () async {
                final name = await _askName('New folder name');
                if (name == null || name.isEmpty) return;
                setState(() {
                  final full = _path.isEmpty ? name : '$_path/$name';
                  _emptyFolders.add(full);
                  _path = full;
                });
              },
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: const Text('New folder'),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Uploading a folder keeps its whole structure. Tap a file\'s ⋮ to rename or move it.',
            style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
          ),
          const SizedBox(height: 10),
          for (final name in folderNames)
            ListTile(
              leading: const Text('📁', style: TextStyle(fontSize: 22)),
              title: Text(name),
              subtitle: subfolders[name] == 0
                  ? const Text('empty — upload or move files here')
                  : Text(
                      '${subfolders[name]} file${subfolders[name] == 1 ? '' : 's'}'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  final full = _path.isEmpty ? name : '$_path/$name';
                  if (v == 'open') {
                    setState(() => _path = full);
                  } else if (v == 'delete') {
                    _deleteFolder(full, files);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'open', child: Text('Open')),
                  PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete folder…',
                          style:
                              TextStyle(color: JamJotColors.recording))),
                ],
              ),
              onTap: () => setState(() =>
                  _path = _path.isEmpty ? name : '$_path/$name'),
            ),
        ],
        if (here.isEmpty && folderNames.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              searching
                  ? 'Nothing matches "$_query" yet.'
                  : (_path.isEmpty
                      ? 'No files yet — upload a PDF, a photo of sheet music, or a whole folder of them.'
                      : 'This folder is empty — upload or move files here.'),
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
            ),
          )
        else
          for (final f in here)
            ListTile(
              leading: const Text('📄', style: TextStyle(fontSize: 22)),
              title: Text(f['title'] as String? ?? 'File'),
              subtitle: Text(searching &&
                      ((f['folder'] as String?) ?? '').isNotEmpty
                  ? '📁 ${f['folder']}'
                  : DateFormat('MMM d, yyyy').format(
                      DateTime.parse(f['created_at'] as String).toLocal())),
              onTap: f['original_path'] == null
                  ? null
                  : () =>
                      _openScoreFile(context, f['original_path'] as String),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'open' && f['original_path'] != null) {
                    _openScoreFile(context, f['original_path'] as String);
                  } else if (v == 'rename') {
                    _rename(f);
                  } else if (v == 'move') {
                    _move(f, files);
                  } else if (v == 'delete') {
                    _deleteFile(f);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'open', child: Text('Open')),
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'move', child: Text('Move to…')),
                  PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete…',
                          style:
                              TextStyle(color: JamJotColors.recording))),
                ],
              ),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------- Assignments tab

class _AssignmentsTab extends ConsumerStatefulWidget {
  const _AssignmentsTab();
  @override
  ConsumerState<_AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends ConsumerState<_AssignmentsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(savedAssignmentsProvider).valueOrNull ?? [];
    final shown = items.where((a) {
      final p = a['payload'] as Map? ?? {};
      return looseMatch(_query, '${p['title'] ?? ''} ${p['book'] ?? ''}');
    }).toList();
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SearchField(
            hint: 'Search assignments…',
            onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => showCreateAssignmentDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Create an assignment'),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _query.isEmpty
                  ? 'No assignments yet — create your first song or task.'
                  : 'Nothing matches "$_query" yet.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
            ),
          )
        else
          for (final a in shown)
            Builder(builder: (context) {
              final p = a['payload'] as Map? ?? {};
              final sub = [
                if ((p['book'] ?? '') != '') p['book'],
                if ((p['pages'] ?? '') != '') 'p. ${p['pages']}',
              ].join(' • ');
              return ListTile(
                leading: const Text('🎼', style: TextStyle(fontSize: 22)),
                title: Text(p['title'] as String? ?? 'Assignment'),
                subtitle: sub.isEmpty ? null : Text(sub),
                onTap: () =>
                    showCreateAssignmentDialog(context, ref, existing: a),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      showCreateAssignmentDialog(context, ref, existing: a);
                    } else if (v == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                JamJotShape.cardRadius),
                            side: JamJotShape.border,
                          ),
                          title: Text('Delete "${p['title']}"?'),
                          content: const Text(
                              'Lessons that already include it keep their own copy — only this library template goes away.'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Keep it')),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(true),
                              style: FilledButton.styleFrom(
                                  backgroundColor: JamJotColors.recording,
                                  minimumSize: const Size(96, 44)),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await JamJotBackend.client
                            .from('saved_assignments')
                            .delete()
                            .eq('id', a['id']);
                        ref.invalidate(savedAssignmentsProvider);
                      }
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete…',
                            style:
                                TextStyle(color: JamJotColors.recording))),
                  ],
                ),
              );
            }),
      ],
    );
  }
}

// -------------------------------------------------------------- Lessons tab

class _LessonsTab extends ConsumerStatefulWidget {
  const _LessonsTab();
  @override
  ConsumerState<_LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends ConsumerState<_LessonsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(savedLessonsProvider).valueOrNull ?? [];
    final shown = items.where((l) {
      final p = l['payload'] as Map? ?? {};
      return looseMatch(_query, p['title'] as String? ?? '');
    }).toList();
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SearchField(
            hint: 'Search lessons…',
            onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => showCreateLessonDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Create a lesson'),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _query.isEmpty
                  ? 'No lessons yet — group assignments into your first lesson.'
                  : 'Nothing matches "$_query" yet.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
            ),
          )
        else
          for (final l in shown)
            Builder(builder: (context) {
              final p = l['payload'] as Map? ?? {};
              final count = (p['assignments'] as List? ?? []).length;
              return ListTile(
                leading: const Text('📚', style: TextStyle(fontSize: 22)),
                title: Text(p['title'] as String? ?? 'Lesson'),
                subtitle:
                    Text('$count assignment${count == 1 ? '' : 's'}'),
                onTap: () =>
                    showCreateLessonDialog(context, ref, existing: l),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      showCreateLessonDialog(context, ref, existing: l);
                    } else if (v == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                JamJotShape.cardRadius),
                            side: JamJotShape.border,
                          ),
                          title: Text('Delete "${p['title']}"?'),
                          content: const Text(
                              'Only this library template goes away — lessons already assigned to students are untouched.'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Keep it')),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(true),
                              style: FilledButton.styleFrom(
                                  backgroundColor: JamJotColors.recording,
                                  minimumSize: const Size(96, 44)),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await JamJotBackend.client
                            .from('saved_lessons')
                            .delete()
                            .eq('id', l['id']);
                        ref.invalidate(savedLessonsProvider);
                      }
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete…',
                            style:
                                TextStyle(color: JamJotColors.recording))),
                  ],
                ),
              );
            }),
      ],
    );
  }
}

// ------------------------------------------------ Create assignment dialog

/// Pops the create-assignment box. Returns the new saved_assignments row.
Future<Map<String, dynamic>?> showCreateAssignmentDialog(
    BuildContext context, WidgetRef ref,
    {Map<String, dynamic>? existing}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _CreateAssignmentDialog(existing: existing),
  );
}

class _CreateAssignmentDialog extends ConsumerStatefulWidget {
  const _CreateAssignmentDialog({this.existing});

  /// When set, the dialog edits this saved assignment instead of creating.
  final Map<String, dynamic>? existing;
  @override
  ConsumerState<_CreateAssignmentDialog> createState() =>
      _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState
    extends ConsumerState<_CreateAssignmentDialog> {
  late final Map<String, dynamic> _p =
      (widget.existing?['payload'] as Map?)?.cast<String, dynamic>() ?? {};
  late final _title = TextEditingController(text: _p['title'] as String? ?? '');
  late final _book = TextEditingController(text: _p['book'] as String? ?? '');
  late final _pages = TextEditingController(text: _p['pages'] as String? ?? '');
  late final _note = TextEditingController(text: _p['note'] as String? ?? '');
  String _fileQuery = '';
  Map<String, dynamic>? _attachedFile;
  bool _prefilledFile = false;
  String _lessonQuery = '';
  final Set<String> _addedToLessons = {};
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _book.dispose();
    _pages.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final uid = JamJotBackend.client.auth.currentUser!.id;
      final payload = {
        'title': _title.text.trim(),
        'book': _book.text.trim(),
        'pages': _pages.text.trim(),
        'note': _note.text.trim(),
        'score_id': _attachedFile?['id'],
      };
      final Map<String, dynamic> row;
      if (widget.existing != null) {
        row = await JamJotBackend.client
            .from('saved_assignments')
            .update({'payload': payload})
            .eq('id', widget.existing!['id'])
            .select()
            .single();
      } else {
        row = await JamJotBackend.client
            .from('saved_assignments')
            .insert({'owner_id': uid, 'payload': payload})
            .select()
            .single();
      }
      ref.invalidate(savedAssignmentsProvider);
      if (mounted) Navigator.of(context).pop(row);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addToLesson(Map<String, dynamic> lesson) async {
    // Library-only: live student lessons are never touched from here.
    final payload = Map<String, dynamic>.from(lesson['payload'] as Map);
    final list = List<Map<String, dynamic>>.from(
        (payload['assignments'] as List? ?? []).cast<Map<String, dynamic>>());
    list.add({
      'title': _title.text.trim(),
      'book': _book.text.trim(),
      'pages': _pages.text.trim(),
      'note': _note.text.trim(),
      'score_id': _attachedFile?['id'],
    });
    payload['assignments'] = list;
    await JamJotBackend.client
        .from('saved_lessons')
        .update({'payload': payload}).eq('id', lesson['id']);
    ref.invalidate(savedLessonsProvider);
    setState(() => _addedToLessons.add(lesson['id'] as String));
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(libraryScoresProvider).valueOrNull ?? [];
    final lessons = ref.watch(savedLessonsProvider).valueOrNull ?? [];
    if (!_prefilledFile && _p['score_id'] != null && files.isNotEmpty) {
      _prefilledFile = true;
      _attachedFile =
          files.where((f) => f['id'] == _p['score_id']).firstOrNull;
    }
    final fileMatches = _fileQuery.isEmpty
        ? <Map<String, dynamic>>[]
        : files
            .where(
                (f) => looseMatch(_fileQuery, f['title'] as String? ?? ''))
            .take(4)
            .toList();
    final lessonMatches = _lessonQuery.isEmpty
        ? <Map<String, dynamic>>[]
        : lessons
            .where((l) => looseMatch(
                _lessonQuery, (l['payload'] as Map?)?['title'] ?? ''))
            .take(4)
            .toList();
    final text = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
        side: JamJotShape.border,
      ),
      title: Text(widget.existing == null
          ? 'Create an assignment'
          : 'Edit assignment'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Song title / assignment name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _book,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(labelText: 'Book name (optional)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pages,
                decoration:
                    const InputDecoration(labelText: 'Page(s) (optional)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Note for the student (optional)'),
              ),
              const SizedBox(height: 14),
              if (_attachedFile != null)
                Chip(
                  avatar: const Text('📄'),
                  label: Text(_attachedFile!['title'] as String? ?? 'File'),
                  onDeleted: () => setState(() => _attachedFile = null),
                )
              else ...[
                TextField(
                  decoration: const InputDecoration(
                      labelText: 'Attach a file: search your library…',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _fileQuery = v),
                ),
                for (final f in fileMatches)
                  ListTile(
                    dense: true,
                    leading: const Text('📄'),
                    title: Text(f['title'] as String? ?? ''),
                    onTap: () => setState(() {
                      _attachedFile = f;
                      _fileQuery = '';
                    }),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    final row = await uploadScoreFile(context, ref);
                    if (row != null) setState(() => _attachedFile = row);
                  },
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('…or upload a new file'),
                ),
              ],
              const Divider(height: 24),
              Text('Add to an existing lesson (optional)',
                  style:
                      text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              TextField(
                decoration: const InputDecoration(
                    labelText: 'Search your lessons…',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _lessonQuery = v),
              ),
              for (final l in lessonMatches)
                ListTile(
                  dense: true,
                  leading: const Text('📚'),
                  title: Text((l['payload'] as Map?)?['title'] ?? ''),
                  trailing: _addedToLessons.contains(l['id'])
                      ? const Text('Added ✓',
                          style: TextStyle(color: JamJotColors.inkSoft))
                      : OutlinedButton(
                          onPressed: _title.text.trim().isEmpty
                              ? null
                              : () => _addToLesson(l),
                          child: const Text('Add'),
                        ),
                ),
              if (_addedToLessons.isNotEmpty)
                Text(
                  'Added to the library copy only — lessons already assigned to students stay as they are.',
                  style:
                      text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
          child: Text(_busy
              ? 'Saving…'
              : (widget.existing == null
                  ? 'Save to assignment library'
                  : 'Save changes')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------- Create lesson dialog

/// The full create-lesson flow. When [student] is given (from a student's
/// profile), the student step is folded into one page and auto-assigned.
Future<void> showCreateLessonDialog(BuildContext context, WidgetRef ref,
    {Map<String, dynamic>? student,
    String? enrollmentId,
    Map<String, dynamic>? existing}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CreateLessonDialog(
        student: student, enrollmentId: enrollmentId, existing: existing),
  );
}

class _CreateLessonDialog extends ConsumerStatefulWidget {
  const _CreateLessonDialog({this.student, this.enrollmentId, this.existing});
  final Map<String, dynamic>? student;

  /// When set, the dialog edits this saved lesson template instead.
  final Map<String, dynamic>? existing;

  /// Which connection the assigned lessons belong to (null = family-run).
  final String? enrollmentId;

  @override
  ConsumerState<_CreateLessonDialog> createState() =>
      _CreateLessonDialogState();
}

class _StudentPlan {
  final notes = TextEditingController();
  final days = TextEditingController(text: '4');
  final minutes = TextEditingController(text: '15');
  DateTime assignOn = DateTime.now();
}

class _CreateLessonDialogState extends ConsumerState<_CreateLessonDialog> {
  final _title = TextEditingController();
  String _assignmentQuery = '';
  final List<Map<String, dynamic>> _picked = []; // assignment payloads
  int _page = 0; // 0 = build lesson, 1 = assign students
  final Map<String, _StudentPlan> _plans = {};
  final Set<String> _checked = {};
  bool _busy = false;

  bool get _singleStudent => widget.student != null;
  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      final payload =
          (widget.existing!['payload'] as Map?)?.cast<String, dynamic>() ??
              {};
      _title.text = payload['title'] as String? ?? '';
      _picked.addAll(((payload['assignments'] as List?) ?? [])
          .map((a) => Map<String, dynamic>.from(a as Map)));
    }
    if (_singleStudent) {
      final id = widget.student!['id'] as String;
      _checked.add(id);
      _plans[id] = _StudentPlan();
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _picked.isEmpty) return;
    setState(() => _busy = true);
    try {
      final uid = JamJotBackend.client.auth.currentUser!.id;
      if (_editing) {
        // Editing changes the library template only; lessons already
        // assigned to students stay exactly as they were.
        await JamJotBackend.client.from('saved_lessons').update({
          'payload': {
            'title': _title.text.trim(),
            'assignments': _picked,
          },
        }).eq('id', widget.existing!['id']);
        ref.invalidate(savedLessonsProvider);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lesson updated.')));
        }
        return;
      }
      // 1) The lesson template, student-free, into the library.
      await JamJotBackend.client.from('saved_lessons').insert({
        'owner_id': uid,
        'payload': {
          'title': _title.text.trim(),
          'assignments': _picked,
        },
      });
      ref.invalidate(savedLessonsProvider);
      // 2) A real lesson for each chosen student.
      for (final sid in _checked) {
        final plan = _plans[sid]!;
        final lesson = await JamJotBackend.client
            .from('lessons')
            .insert({
              'student_id': sid,
              'created_by': uid,
              'title': _title.text.trim(),
              'lesson_note': plan.notes.text.trim(),
              'goal_days': int.tryParse(plan.days.text.trim()) ?? 4,
              'goal_minutes': int.tryParse(plan.minutes.text.trim()) ?? 15,
              'week_start':
                  DateFormat('yyyy-MM-dd').format(plan.assignOn),
              if (widget.enrollmentId != null)
                'enrollment_id': widget.enrollmentId,
            })
            .select()
            .single();
        for (var i = 0; i < _picked.length; i++) {
          final a = _picked[i];
          await JamJotBackend.client.from('assignments').insert({
            'lesson_id': lesson['id'],
            'title': a['title'],
            'song_note': a['note'] ?? '',
            'score_id': a['score_id'],
            'order_idx': i,
          });
        }
        ref.invalidate(currentLessonProvider(sid));
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_checked.isEmpty
                ? 'Lesson saved to your library.'
                : 'Lesson saved & assigned to ${_checked.length} student${_checked.length == 1 ? '' : 's'}.')));
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildPageOne(TextTheme text) {
    final saved = ref.watch(savedAssignmentsProvider).valueOrNull ?? [];
    final matches = _assignmentQuery.isEmpty
        ? <Map<String, dynamic>>[]
        : saved
            .where((a) => looseMatch(_assignmentQuery,
                '${(a['payload'] as Map?)?['title'] ?? ''} ${(a['payload'] as Map?)?['book'] ?? ''}'))
            .take(4)
            .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Lesson name'),
        ),
        const SizedBox(height: 12),
        if (_picked.isNotEmpty) ...[
          Text('In this lesson:',
              style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _picked.length; i++)
                InputChip(
                  avatar: const Text('🎼'),
                  label: Text(_picked[i]['title'] as String? ?? ''),
                  onPressed: () => _editAssignmentNote(i),
                  onDeleted: () => setState(() => _picked.removeAt(i)),
                ),
            ],
          ),
          Text('Tap a song to add a note the student sees while practicing.',
              style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft)),
          const SizedBox(height: 10),
        ],
        TextField(
          decoration: const InputDecoration(
              labelText: 'Search your assignments to add…',
              prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => _assignmentQuery = v),
        ),
        for (final a in matches)
          ListTile(
            dense: true,
            leading: const Text('🎼'),
            title: Text((a['payload'] as Map?)?['title'] ?? ''),
            subtitle: ((a['payload'] as Map?)?['book'] ?? '') == ''
                ? null
                : Text((a['payload'] as Map?)?['book'] ?? ''),
            onTap: () => setState(() {
              _picked.add(
                  Map<String, dynamic>.from(a['payload'] as Map));
              _assignmentQuery = '';
            }),
          ),
        TextButton.icon(
          onPressed: () async {
            final row = await showCreateAssignmentDialog(context, ref);
            if (row != null) {
              setState(() => _picked
                  .add(Map<String, dynamic>.from(row['payload'] as Map)));
            }
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text("…or create a new assignment"),
        ),
        if (_singleStudent) ...[
          const Divider(height: 24),
          _studentPlanFields(
              widget.student!['display_name'] as String,
              _plans[widget.student!['id']]!,
              text),
        ],
      ],
    );
  }

  Future<void> _editAssignmentNote(int index) async {
    final controller =
        TextEditingController(text: _picked[index]['note'] as String? ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
          side: JamJotShape.border,
        ),
        title: Text(_picked[index]['title'] as String? ?? 'Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              labelText: 'Note shown while practicing (optional)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved != null) {
      setState(() => _picked[index]['note'] = saved.trim());
    }
  }

  Widget _studentPlanFields(String name, _StudentPlan plan, TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(name, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: plan.notes,
          textCapitalization: TextCapitalization.sentences,
          decoration:
              const InputDecoration(labelText: 'Lesson notes / reminders'),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: plan.days,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Days goal'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: plan.minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Min/day goal'),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: plan.assignOn,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => plan.assignOn = picked);
          },
          icon: const Icon(Icons.event, size: 18),
          label: Text(
              'Assign on ${DateFormat('EEE, MMM d').format(plan.assignOn)}'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPageTwo(TextTheme text) {
    final students = ref.watch(myStudentsProvider).valueOrNull ?? [];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Who is this lesson for?',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        for (final s in students)
          CheckboxListTile(
            dense: true,
            value: _checked.contains(s['id']),
            title: Text(s['display_name'] as String),
            onChanged: (v) => setState(() {
              final id = s['id'] as String;
              if (v == true) {
                _checked.add(id);
                _plans[id] ??= _StudentPlan();
              } else {
                _checked.remove(id);
              }
            }),
          ),
        const SizedBox(height: 8),
        for (final s in students)
          if (_checked.contains(s['id']))
            _studentPlanFields(
                s['display_name'] as String, _plans[s['id']]!, text),
        if (_checked.isEmpty)
          Text(
            'No one checked — the lesson will save to your library only.',
            style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canContinue = _title.text.trim().isNotEmpty && _picked.isNotEmpty;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JamJotShape.cardRadius),
        side: JamJotShape.border,
      ),
      title: Text(_editing
          ? 'Edit lesson'
          : _singleStudent
              ? 'Lesson for ${widget.student!['display_name']}'
              : (_page == 0 ? 'Create a lesson' : 'Assign the lesson')),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: _page == 0 ? _buildPageOne(text) : _buildPageTwo(text),
        ),
      ),
      actions: [
        if (_page == 1)
          TextButton(
            onPressed: () => setState(() => _page = 0),
            child: const Text('Back'),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        if (_page == 0 && !_singleStudent && !_editing)
          FilledButton(
            onPressed: canContinue ? () => setState(() => _page = 1) : null,
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Next'),
          )
        else
          FilledButton(
            onPressed: _busy || !canContinue ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            child: Text(_busy
                ? 'Saving…'
                : (_editing ? 'Save changes' : 'Save lesson')),
          ),
      ],
    );
  }
}
