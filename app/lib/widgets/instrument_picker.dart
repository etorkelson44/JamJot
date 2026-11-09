import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/instruments.dart';
import '../services/instrument_suggestions.dart';
import '../theme/jamjot_theme.dart';
import 'instrument_icon.dart';

/// One search box for instruments (JJ-036-C). Matching instruments appear
/// below it as you type; the outline wraps only what is showing.
/// Everything runs on the device. Nothing is sent anywhere until the
/// student taps "Yes, add it" for an instrument that isn't on the list.
class InstrumentSearchField extends StatefulWidget {
  const InstrumentSearchField({
    super.key,
    required this.onChosen,
    this.exclude = const {},
    this.autofocus = false,
    this.hint = 'Search instruments',
  });

  /// The chosen name: a list name, or the tidied typed-in name.
  final ValueChanged<String> onChosen;

  /// Names already chosen (not offered again).
  final Set<String> exclude;
  final bool autofocus;
  final String hint;

  @override
  State<InstrumentSearchField> createState() => _InstrumentSearchFieldState();
}

class _InstrumentSearchFieldState extends State<InstrumentSearchField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  int _highlight = -1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _highlight = -1));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _query => _controller.text;

  List<Instrument> get _matches => searchInstruments(_query)
      .where((i) => !widget.exclude.contains(i.name))
      .toList();

  List<Instrument> get _typos => didYouMean(_query)
      .where((i) => !widget.exclude.contains(i.name))
      .toList();

  /// What the arrow keys move through right now.
  List<Instrument> get _choices {
    if (normalizeInstrument(_query).isEmpty) return const [];
    final m = _matches;
    return m.isNotEmpty ? m : _typos;
  }

  void _choose(String name) {
    _controller.clear();
    widget.onChosen(name);
  }

  void _clear() {
    _controller.clear();
    _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final choices = _choices;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown && choices.isNotEmpty) {
      setState(() => _highlight = (_highlight + 1) % choices.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && choices.isNotEmpty) {
      setState(() => _highlight =
          _highlight <= 0 ? choices.length - 1 : _highlight - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_highlight >= 0 && _highlight < choices.length) {
        _choose(choices[_highlight].name);
        return KeyEventResult.handled;
      }
      if (_matches.length == 1) {
        _choose(_matches.first.name);
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _clear();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _row(Instrument i, int index) {
    final lit = index == _highlight;
    return InkWell(
      onTap: () => _choose(i.name),
      child: Container(
        color: lit ? JamJotColors.blueberryTint : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          InstrumentIcon(i.name, size: 36),
          const SizedBox(width: 12),
          Expanded(
              child: Text(i.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }

  Widget _noMatch(TextTheme text) {
    final problem = instrumentInputProblem(_query);
    if (problem != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Text(problem,
            style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft)),
      );
    }
    final name = tidyInstrumentName(_query);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('"$name" isn\'t on our list yet. Add "$name"?',
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
              'We don\'t have a picture for this one yet, so we\'ll use a '
              'placeholder. We\'ll tell our team so it can join the list!',
              style: text.bodyMedium?.copyWith(color: JamJotColors.inkSoft)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(
              onPressed: () {
                InstrumentSuggestions.submit(name);
                _choose(name);
              },
              child: const Text('Yes, add it'),
            ),
            OutlinedButton(onPressed: _clear, child: const Text('Go back')),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final typed = normalizeInstrument(_query).isNotEmpty;
    final matches = typed ? _matches : const <Instrument>[];
    final typos = typed && matches.isEmpty ? _typos : const <Instrument>[];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: JamJotColors.ink, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Focus(
              onKeyEvent: _onKey,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (_matches.length == 1) _choose(_matches.first.name);
                },
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: typed
                      ? IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close),
                          onPressed: _clear)
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (matches.isNotEmpty) ...[
              const Divider(height: 1),
              for (var i = 0; i < matches.length; i++) _row(matches[i], i),
              const SizedBox(height: 4),
            ],
            if (typed && matches.isEmpty) ...[
              const Divider(height: 1),
              if (typos.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  child: Text('Did you mean...?',
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                for (var i = 0; i < typos.length; i++) _row(typos[i], i),
              ],
              _noMatch(text),
            ],
          ],
        ),
      ),
    );
  }
}

/// The chosen instruments, each with its icon and a "Change" link, plus
/// the search box when one is being picked.
class InstrumentPicker extends StatefulWidget {
  const InstrumentPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.multiple = true,
    this.autofocus = false,
  });

  final List<String> value;
  final ValueChanged<List<String>> onChanged;

  /// Allow more than one instrument ("Add another instrument").
  final bool multiple;
  final bool autofocus;

  @override
  State<InstrumentPicker> createState() => _InstrumentPickerState();
}

class _InstrumentPickerState extends State<InstrumentPicker> {
  /// Which entry the search box is replacing; null = adding a new one.
  int? _changing;
  bool _adding = false;

  void _picked(String name) {
    final list = [...widget.value];
    if (_changing != null && _changing! < list.length) {
      list[_changing!] = name;
    } else if (!list.contains(name)) {
      list.add(name);
    }
    setState(() {
      _changing = null;
      _adding = false;
    });
    widget.onChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final searching = value.isEmpty || _adding || _changing != null;
    Widget search() => InstrumentSearchField(
          autofocus: widget.autofocus || value.isNotEmpty,
          exclude: {
            for (var i = 0; i < value.length; i++)
              if (i != _changing) value[i]
          },
          onChosen: _picked,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < value.length; i++)
          if (_changing == i)
            Padding(
                padding: const EdgeInsets.only(bottom: 8), child: search())
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                InstrumentIcon(value[i], size: 40),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(value[i],
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700))),
                TextButton(
                  onPressed: () => setState(() {
                    _changing = i;
                    _adding = false;
                  }),
                  child: const Text('Change'),
                ),
                if (widget.multiple && value.length > 1)
                  IconButton(
                    tooltip: 'Remove ${value[i]}',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() => _changing = null);
                      widget.onChanged([...value]..removeAt(i));
                    },
                  ),
              ]),
            ),
        if (searching && _changing == null) search(),
        if (searching && value.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() {
                _changing = null;
                _adding = false;
              }),
              child: const Text('Cancel'),
            ),
          ),
        if (!searching && widget.multiple)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _adding = true),
              icon: const Icon(Icons.add),
              label: const Text('Add another instrument'),
            ),
          ),
      ],
    );
  }
}
