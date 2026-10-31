import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:url_launcher/url_launcher.dart';

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

/// Picks a file from the device and saves it to the library.
/// Returns the new scores row, or null if cancelled.
Future<Map<String, dynamic>?> uploadScoreFile(
    BuildContext context, WidgetRef ref) async {
  final picked = await FilePicker.platform
      .pickFiles(type: FileType.custom, allowedExtensions: [
    'pdf', 'png', 'jpg', 'jpeg', 'xml', 'musicxml', 'mxl'
  ], withData: true);
  final file = picked?.files.firstOrNull;
  if (file == null || file.bytes == null) return null;
  final uid = JamJotBackend.client.auth.currentUser!.id;
  final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final path = '$uid/${DateTime.now().millisecondsSinceEpoch}-$safeName';
  try {
    await JamJotBackend.client.storage
        .from('scores')
        .uploadBinary(path, file.bytes!, fileOptions: const FileOptions());
    final title = file.name.contains('.')
        ? file.name.substring(0, file.name.lastIndexOf('.'))
        : file.name;
    final row = await JamJotBackend.client
        .from('scores')
        .insert({
          'owner_id': uid,
          'title': title,
          'original_path': path,
          'meta': {'file_name': file.name, 'size': file.size},
        })
        .select()
        .single();
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

// ---------------------------------------------------------------- Files tab

class _FilesTab extends ConsumerStatefulWidget {
  const _FilesTab();
  @override
  ConsumerState<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends ConsumerState<_FilesTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(libraryScoresProvider).valueOrNull ?? [];
    final shown = files
        .where((f) => looseMatch(_query, f['title'] as String? ?? ''))
        .toList();
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SearchField(
            hint: 'Search music & books…',
            onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => uploadScoreFile(context, ref),
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload file'),
        ),
        const SizedBox(height: 8),
        Text(
          'Soon: connect to score stores & the sheet-music converter right here.',
          style: text.bodySmall?.copyWith(color: JamJotColors.inkSoft),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _query.isEmpty
                  ? 'No files yet — upload your first PDF or photo of sheet music.'
                  : 'Nothing matches "$_query" yet.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft),
            ),
          )
        else
          for (final f in shown)
            ListTile(
              leading: const Text('📄', style: TextStyle(fontSize: 22)),
              title: Text(f['title'] as String? ?? 'File'),
              subtitle: Text(DateFormat('MMM d, yyyy')
                  .format(DateTime.parse(f['created_at'] as String).toLocal())),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: f['original_path'] == null
                  ? null
                  : () =>
                      _openScoreFile(context, f['original_path'] as String),
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
              );
            }),
      ],
    );
  }
}

// ------------------------------------------------ Create assignment dialog

/// Pops the create-assignment box. Returns the new saved_assignments row.
Future<Map<String, dynamic>?> showCreateAssignmentDialog(
    BuildContext context, WidgetRef ref) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => const _CreateAssignmentDialog(),
  );
}

class _CreateAssignmentDialog extends ConsumerStatefulWidget {
  const _CreateAssignmentDialog();
  @override
  ConsumerState<_CreateAssignmentDialog> createState() =>
      _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState
    extends ConsumerState<_CreateAssignmentDialog> {
  final _title = TextEditingController();
  final _book = TextEditingController();
  final _pages = TextEditingController();
  final _note = TextEditingController();
  String _fileQuery = '';
  Map<String, dynamic>? _attachedFile;
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
      final row = await JamJotBackend.client
          .from('saved_assignments')
          .insert({
            'owner_id': uid,
            'payload': {
              'title': _title.text.trim(),
              'book': _book.text.trim(),
              'pages': _pages.text.trim(),
              'note': _note.text.trim(),
              'score_id': _attachedFile?['id'],
            },
          })
          .select()
          .single();
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
      title: const Text('Create an assignment'),
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
          child: Text(_busy ? 'Saving…' : 'Save to assignment library'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------- Create lesson dialog

/// The full create-lesson flow. When [student] is given (from a student's
/// profile), the student step is folded into one page and auto-assigned.
Future<void> showCreateLessonDialog(BuildContext context, WidgetRef ref,
    {Map<String, dynamic>? student}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CreateLessonDialog(student: student),
  );
}

class _CreateLessonDialog extends ConsumerStatefulWidget {
  const _CreateLessonDialog({this.student});
  final Map<String, dynamic>? student;

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

  @override
  void initState() {
    super.initState();
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
      title: Text(_singleStudent
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
        if (_page == 0 && !_singleStudent)
          FilledButton(
            onPressed: canContinue ? () => setState(() => _page = 1) : null,
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Next'),
          )
        else
          FilledButton(
            onPressed: _busy || !canContinue ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            child: Text(_busy ? 'Saving…' : 'Save lesson'),
          ),
      ],
    );
  }
}
