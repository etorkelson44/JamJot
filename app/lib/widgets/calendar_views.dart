import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_entry.dart';
import 'ask_maestro.dart' show MaestroSearching;

/// All profile views share the calendar structure and inherit their own theme.
class CalendarViews extends StatefulWidget {
  const CalendarViews(
      {super.key,
      required this.entries,
      required this.detailBuilder,
      this.now});
  final List<CalendarEntry> entries;
  final Widget Function(BuildContext, CalendarEntry) detailBuilder;
  final DateTime Function()? now;
  @override
  State<CalendarViews> createState() => _CalendarViewsState();
}

class _CalendarViewsState extends State<CalendarViews>
    with WidgetsBindingObserver {
  String _mode = 'agenda';
  late DateTime _anchor, _today;
  Timer? _midnight;
  final _monthScroll = ScrollController();
  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _anchor = _today = calendarDay(_now());
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    if (widget.now != null) return; // Deterministic preview/test clocks.
    final now = _now();
    _midnight = Timer(calendarDayOffset(now, 1).difference(now), _refreshToday);
  }

  void _refreshToday() {
    if (!mounted) return;
    final next = calendarDay(_now());
    setState(() {
      if (_anchor == _today) _anchor = next;
      _today = next;
    });
    _scheduleMidnight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshToday();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _monthScroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  List<CalendarEntry> _on(DateTime day) =>
      widget.entries.where((entry) => entry.occursOn(day)).toList();
  void _move(int direction) => setState(() {
        _anchor = switch (_mode) {
          'day' => calendarDayOffset(_anchor, direction),
          'week' => calendarDayOffset(_anchor, 7 * direction),
          _ => DateTime(_anchor.year, _anchor.month + direction, 1),
        };
      });
  String get _period => switch (_mode) {
        'day' => DateFormat('MMMM yyyy').format(_anchor),
        'week' => '${DateFormat('MMM d').format(calendarSunday(_anchor))} – '
            '${DateFormat('MMM d, yyyy').format(calendarDayOffset(calendarSunday(_anchor), 6))}',
        _ => DateFormat('MMMM yyyy').format(_anchor),
      };

  void _open(CalendarEntry entry) {
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        constraints: BoxConstraints(
            maxWidth: 640, maxHeight: MediaQuery.sizeOf(context).height * .85),
        builder: (context) => SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(
                                DateFormat('EEEE, MMMM d, yyyy')
                                    .format(entry.start),
                                style:
                                    Theme.of(context).textTheme.titleMedium)),
                        IconButton(
                            tooltip: 'Close event details',
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context))
                      ]),
                      const SizedBox(height: 12),
                      widget.detailBuilder(context, entry),
                    ]))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final colors = theme.colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final view in const {
              'day': 'Day',
              'week': 'Week',
              'month': 'Month',
              'agenda': 'All'
            }.entries)
              ChoiceChip(
                  key: ValueKey('calendar-view-${view.key}'),
                  label: Text(view.value),
                  selected: _mode == view.key,
                  selectedColor: colors.primary.withValues(alpha: .12),
                  checkmarkColor: colors.primary,
                  labelStyle:
                      text.labelLarge?.copyWith(color: colors.onSurface),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => setState(() => _mode = view.key))
          ]),
      const SizedBox(height: 16),
      if (_mode != 'agenda') ...[
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(_period, style: text.titleLarge),
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    tooltip: 'Previous ${_mode == 'day' ? 'day' : _mode}',
                    onPressed: () => _move(-1),
                    icon: const Icon(Icons.chevron_left)),
                TextButton(
                    onPressed: () =>
                        setState(() => _anchor = calendarDay(_now())),
                    child: const Text('Today')),
                IconButton(
                    tooltip: 'Next ${_mode == 'day' ? 'day' : _mode}',
                    onPressed: () => _move(1),
                    icon: const Icon(Icons.chevron_right)),
              ])
            ]),
        const SizedBox(height: 16),
      ],
      switch (_mode) {
        'day' => _day(_anchor),
        'week' => _week(),
        'month' => _month(),
        _ => _agenda(),
      },
    ]);
  }

  Widget _dateHeading(DateTime date,
      {bool prominent = false, bool includeYear = false}) {
    final theme = Theme.of(context);
    final today = calendarDay(date) == _today;
    return Semantics(
        header: true,
        child: Container(
            key: ValueKey('date-${calendarDateKey(date)}'),
            padding: EdgeInsets.all(prominent ? 20 : 12),
            decoration: BoxDecoration(
                color: today
                    ? theme.colorScheme.primary.withValues(alpha: .09)
                    : null,
                borderRadius: BorderRadius.circular(12)),
            child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                      DateFormat(prominent
                              ? 'EEEE, MMMM d'
                              : includeYear
                                  ? 'EEEE, MMM d, yyyy'
                                  : 'EEEE, MMM d')
                          .format(date),
                      style: (prominent
                              ? theme.textTheme.headlineSmall
                              : theme.textTheme.titleMedium)
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (today)
                    Text('Today',
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700)),
                ])));
  }

  Widget _day(DateTime date, {bool prominent = true}) {
    final entries = _on(date);
    return Column(
        key: ValueKey('day-${calendarDateKey(date)}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dateHeading(date, prominent: prominent),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                child: Text('Nothing scheduled this day.',
                    style: Theme.of(context).textTheme.bodyMedium)),
          for (final entry in entries)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: widget.detailBuilder(context, entry)),
        ]);
  }

  Widget _week() {
    final sunday = calendarSunday(_anchor);
    final days = List.generate(7, (i) => calendarDayOffset(sunday, i));
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 980 ||
          MediaQuery.textScalerOf(context).scale(14) > 19) {
        return Column(children: [
          for (final day in days)
            Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _day(day, prominent: false))
        ]);
      }
      return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final day in days)
          Expanded(child: _cell(day, minHeight: 220, week: true))
      ]));
    });
  }

  Widget _month() => LayoutBuilder(builder: (context, constraints) {
        final first = DateTime(_anchor.year, _anchor.month, 1);
        final beginning = calendarSunday(first);
        final days = DateTime(_anchor.year, _anchor.month + 1, 0).day;
        final weeks = ((first.weekday % 7 + days) / 7).ceil();
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final width =
            math.max(constraints.maxWidth, 7.0 * 112.0 * math.max(1.0, scale));
        final scrolls = width > constraints.maxWidth;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (scrolls)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                        'Scroll across to see Sunday–Saturday. Tap an event for details.',
                        style: Theme.of(context).textTheme.bodySmall)),
              Scrollbar(
                  controller: _monthScroll,
                  thumbVisibility: scrolls,
                  notificationPredicate: (notification) =>
                      notification.depth == 0,
                  child: SingleChildScrollView(
                      controller: _monthScroll,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 14),
                      child: SizedBox(
                          width: width,
                          child: Column(children: [
                            Row(children: [
                              for (final name in const [
                                'Sun',
                                'Mon',
                                'Tue',
                                'Wed',
                                'Thu',
                                'Fri',
                                'Sat'
                              ])
                                Expanded(
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        child: Text(name,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w700))))
                            ]),
                            for (var week = 0; week < weeks; week++)
                              IntrinsicHeight(
                                  child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                    for (var weekday = 0;
                                        weekday < 7;
                                        weekday++)
                                      Expanded(
                                          child: _cell(
                                              calendarDayOffset(beginning,
                                                  week * 7 + weekday),
                                              minHeight: width / 7,
                                              outside: calendarDayOffset(
                                                          beginning,
                                                          week * 7 + weekday)
                                                      .month !=
                                                  _anchor.month))
                                  ])),
                          ])))),
            ]);
      });

  Widget _cell(DateTime date,
      {required double minHeight, bool week = false, bool outside = false}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final today = date == _today;
    final entries = _on(date);
    return Container(
        key: ValueKey('cell-${calendarDateKey(date)}'),
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: today
                ? colors.primary.withValues(alpha: .08)
                : outside
                    ? theme.scaffoldBackgroundColor
                    : (theme.cardTheme.color ?? colors.surface),
            border: Border.all(
                color: today
                    ? colors.primary.withValues(alpha: .7)
                    : colors.onSurface.withValues(alpha: .22),
                width: .5)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextButton(
              key: ValueKey('open-day-${calendarDateKey(date)}'),
              style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  foregroundColor: colors.onSurface,
                  minimumSize: const Size(48, 48)),
              onPressed: () => setState(() {
                    _anchor = date;
                    _mode = 'day';
                  }),
              child: Semantics(
                  label:
                      '${DateFormat('EEEE, MMMM d, yyyy').format(date)}${today ? ', Today' : ''}',
                  excludeSemantics: true,
                  child: Column(children: [
                    Text(
                        week
                            ? DateFormat('EEE').format(date)
                            : (outside
                                ? DateFormat('MMM d').format(date)
                                : '${date.day}'),
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (week)
                      Text(DateFormat('MMM d').format(date),
                          style: theme.textTheme.bodySmall),
                    if (today)
                      Text('Today',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                  ]))),
          if (week && entries.isEmpty)
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text('Nothing scheduled',
                    style: theme.textTheme.bodySmall)),
          for (final entry in entries)
            Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _CalendarEntryButton(
                    entry: entry, onTap: () => _open(entry))),
        ]));
  }

  Widget _agenda() {
    if (widget.entries.isEmpty) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(children: [
                    Semantics(
                        label:
                            'Maestro Marmalade searching with his magnifying glass',
                        child: const MaestroSearching(size: 170)),
                    const SizedBox(height: 20),
                    Text(
                        'I’ve searched every measure… no jams on the calendar yet!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Text(
                        'When you, your teacher, or your studio adds an event, it’ll show up here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ]))));
    }
    final groups = <DateTime, List<CalendarEntry>>{};
    for (final entry in widget.entries) {
      (groups[calendarDay(entry.start)] ??= []).add(entry);
    }
    final dates = groups.keys.toList()..sort();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final date in dates) ...[
        _dateHeading(date, includeYear: true),
        const SizedBox(height: 12),
        for (final entry in groups[date]!)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: widget.detailBuilder(context, entry)),
        const SizedBox(height: 12),
      ],
    ]);
  }
}

class _CalendarEntryButton extends StatelessWidget {
  const _CalendarEntryButton({required this.entry, required this.onTap});
  final CalendarEntry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
        color: theme.colorScheme.primary.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Semantics(
                button: true,
                label:
                    '${entry.title}, ${entry.isLesson ? 'Practice lesson' : DateFormat('h:mm a').format(entry.start)}${entry.cancelled ? ', Cancelled' : ''}',
                excludeSemantics: true,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  entry.isLesson
                                      ? 'Practice lesson'
                                      : DateFormat('h:mm a')
                                          .format(entry.start),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 2),
                              Text(entry.title,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                      decoration: entry.cancelled
                                          ? TextDecoration.lineThrough
                                          : null)),
                              if (entry.cancelled)
                                Text('Cancelled',
                                    style: theme.textTheme.labelSmall),
                            ]))))));
  }
}
