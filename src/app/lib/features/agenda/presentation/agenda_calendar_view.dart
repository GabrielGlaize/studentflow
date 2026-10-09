import 'package:flutter/material.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';

/// Vue calendrier de l'agenda : devoirs de la classe, évaluations, tâches et
/// événements, école et entreprise réunis. Semaine par défaut, mois en option ;
/// on balaie d'une période à l'autre et on touche un jour pour le détail.
enum AgendaEntryKind { homework, evaluation, task, event }

extension AgendaEntryKindStyle on AgendaEntryKind {
  String get label => switch (this) {
    AgendaEntryKind.homework => 'Devoirs',
    AgendaEntryKind.evaluation => 'Évaluations',
    AgendaEntryKind.task => 'Tâches',
    AgendaEntryKind.event => 'Événements',
  };

  String get singular => switch (this) {
    AgendaEntryKind.homework => 'devoir',
    AgendaEntryKind.evaluation => 'évaluation',
    AgendaEntryKind.task => 'tâche',
    AgendaEntryKind.event => 'événement',
  };

  IconData get icon => switch (this) {
    AgendaEntryKind.homework => Icons.assignment_outlined,
    AgendaEntryKind.evaluation => Icons.grading_outlined,
    AgendaEntryKind.task => Icons.check_circle_outline,
    AgendaEntryKind.event => Icons.event_outlined,
  };

  Color color(BuildContext context) => switch (this) {
    AgendaEntryKind.homework => context.sfShared,
    AgendaEntryKind.evaluation => context.sfEvaluation,
    AgendaEntryKind.task => context.sfPersonal,
    AgendaEntryKind.event =>
      context.sfIsDark ? const Color(0xFFC3B8F2) : const Color(0xFF6A5AA8),
  };
}

class AgendaCalendarEntry {
  const AgendaCalendarEntry({
    required this.id,
    required this.kind,
    required this.day,
    required this.title,
    this.time,
    this.isCompany = false,
  });

  final String id;
  final AgendaEntryKind kind;

  /// Jour seul (sans heure).
  final DateTime day;
  final String title;

  /// « 14:00 » pour un événement ou une échéance à heure précise.
  final String? time;

  /// Entreprise ou recherche d'alternance (sinon : école / perso).
  final bool isCompany;
}

enum AgendaCalendarScale { week, month }

class AgendaCalendarView extends StatefulWidget {
  const AgendaCalendarView({
    required this.entries,
    required this.onOpenDay,
    required this.onRefresh,
    super.key,
  });

  final List<AgendaCalendarEntry> entries;
  final ValueChanged<DateTime> onOpenDay;
  final Future<void> Function() onRefresh;

  @override
  State<AgendaCalendarView> createState() => _AgendaCalendarViewState();
}

class _AgendaCalendarViewState extends State<AgendaCalendarView> {
  static const _origin = 5000;

  late final DateTime _today;
  late DateTime _focus;
  AgendaCalendarScale _scale = AgendaCalendarScale.week;
  late PageController _controller;
  final Set<AgendaEntryKind> _hidden = {};

  @override
  void initState() {
    super.initState();
    _today = DateUtils.dateOnly(DateTime.now());
    _focus = _today;
    _controller = PageController(initialPage: _indexOf(_focus));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _indexOf(DateTime day) => switch (_scale) {
    AgendaCalendarScale.week =>
      _origin +
          (StudyFlowDates.mondayOf(
                    day,
                  ).difference(StudyFlowDates.mondayOf(_today)).inDays /
                  7)
              .round(),
    AgendaCalendarScale.month =>
      _origin + (day.year - _today.year) * 12 + (day.month - _today.month),
  };

  /// Premier jour de la page : lundi de la semaine, ou 1er du mois.
  DateTime _pageStart(int index) => switch (_scale) {
    AgendaCalendarScale.week => StudyFlowDates.addDays(
      StudyFlowDates.mondayOf(_today),
      (index - _origin) * 7,
    ),
    AgendaCalendarScale.month => DateTime(
      _today.year,
      _today.month + index - _origin,
    ),
  };

  Map<DateTime, List<AgendaCalendarEntry>> get _byDay {
    final result = <DateTime, List<AgendaCalendarEntry>>{};
    for (final entry in widget.entries) {
      if (_hidden.contains(entry.kind)) continue;
      result.putIfAbsent(DateUtils.dateOnly(entry.day), () => []).add(entry);
    }
    for (final entries in result.values) {
      entries.sort(_byKindThenTime);
    }
    return result;
  }

  void _setScale(AgendaCalendarScale scale) {
    if (scale == _scale) return;
    setState(() {
      _scale = scale;
      _controller.dispose();
      _controller = PageController(initialPage: _indexOf(_focus));
    });
  }

  void _goToToday() {
    _controller.animateToPage(
      _indexOf(_today),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final byDay = _byDay;
    final focusStart = _pageStart(_indexOf(_focus));
    final atToday = _indexOf(_focus) == _indexOf(_today);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          child: Row(
            children: [
              SegmentedButton<AgendaCalendarScale>(
                key: const ValueKey('agenda-calendar-scale'),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(
                    value: AgendaCalendarScale.week,
                    label: Text('Semaine'),
                  ),
                  ButtonSegment(
                    value: AgendaCalendarScale.month,
                    label: Text('Mois'),
                  ),
                ],
                selected: {_scale},
                onSelectionChanged: (value) => _setScale(value.single),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _periodLabel(focusStart),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: context.sfText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: _scale == AgendaCalendarScale.week
                    ? 'Cette semaine'
                    : 'Ce mois-ci',
                onPressed: atToday ? null : _goToToday,
                icon: const Icon(Icons.today_outlined),
              ),
            ],
          ),
        ),
        _KindFilters(
          hidden: _hidden,
          counts: {
            for (final kind in AgendaEntryKind.values)
              kind: widget.entries.where((x) => x.kind == kind).length,
          },
          onToggle: (kind) => setState(() {
            if (!_hidden.remove(kind)) _hidden.add(kind);
          }),
        ),
        Expanded(
          child: PageView.builder(
            key: ValueKey('agenda-calendar-${_scale.name}'),
            controller: _controller,
            onPageChanged: (index) => setState(() {
              final start = _pageStart(index);
              _focus = _scale == AgendaCalendarScale.week
                  ? start
                  : (start.year == _today.year && start.month == _today.month
                        ? _today
                        : start);
            }),
            itemBuilder: (context, index) {
              final start = _pageStart(index);
              return RefreshIndicator(
                onRefresh: widget.onRefresh,
                child: _scale == AgendaCalendarScale.week
                    ? _WeekPage(
                        monday: start,
                        today: _today,
                        byDay: byDay,
                        onOpenDay: widget.onOpenDay,
                      )
                    : _MonthPage(
                        firstDay: start,
                        today: _today,
                        byDay: byDay,
                        onOpenDay: widget.onOpenDay,
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _periodLabel(DateTime start) {
    if (_scale == AgendaCalendarScale.month) {
      return StudyFlowFormat.monthYear(start);
    }
    final end = StudyFlowDates.addDays(start, 6);
    return start.month == end.month
        ? '${start.day} – ${end.day} ${StudyFlowFormat.monthYear(end).toLowerCase()}'
        : '${start.day}/${start.month} – ${end.day}/${end.month}';
  }
}

int _byKindThenTime(AgendaCalendarEntry a, AgendaCalendarEntry b) {
  final kind = a.kind.index.compareTo(b.kind.index);
  if (kind != 0) return kind;
  return (a.time ?? '').compareTo(b.time ?? '');
}

/// Légende et filtre à la fois : toucher une catégorie la masque.
class _KindFilters extends StatelessWidget {
  const _KindFilters({
    required this.hidden,
    required this.counts,
    required this.onToggle,
  });

  final Set<AgendaEntryKind> hidden;
  final Map<AgendaEntryKind, int> counts;
  final ValueChanged<AgendaEntryKind> onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          for (final kind in AgendaEntryKind.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                key: ValueKey('agenda-filter-${kind.name}'),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                selected: !hidden.contains(kind),
                onSelected: (_) => onToggle(kind),
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: hidden.contains(kind)
                        ? context.sfLine
                        : kind.color(context),
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text('${kind.label} · ${counts[kind] ?? 0}'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Semaine : une ligne par jour, les éléments en pastilles compactes.
class _WeekPage extends StatelessWidget {
  const _WeekPage({
    required this.monday,
    required this.today,
    required this.byDay,
    required this.onOpenDay,
  });

  static const _visiblePerDay = 4;

  final DateTime monday;
  final DateTime today;
  final Map<DateTime, List<AgendaCalendarEntry>> byDay;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 112),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = StudyFlowDates.addDays(monday, index);
        final entries = byDay[day] ?? const <AgendaCalendarEntry>[];
        final isToday = DateUtils.isSameDay(day, today);
        final isPast = day.isBefore(today);

        // Jour vide : une ligne fine, pour que les jours chargés ressortent.
        if (entries.isEmpty && !isToday) {
          return InkWell(
            key: ValueKey('agenda-week-day-${day.day}'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => onOpenDay(day),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
              child: Opacity(
                opacity: isPast ? 0.5 : 0.8,
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${StudyFlowFormat.weekdayShort(day)} ${day.day}',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: context.sfMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(height: 1, color: context.sfLine),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: isToday ? context.sfSharedSoft : context.sfCard,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              key: ValueKey('agenda-week-day-${day.day}'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => onOpenDay(day),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isToday ? context.sfShared : context.sfLine,
                  ),
                ),
                child: Opacity(
                  opacity: isPast ? 0.6 : 1,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 44,
                        child: Column(
                          children: [
                            Text(
                              StudyFlowFormat.weekdayShort(day),
                              style: TextStyle(
                                color: isToday
                                    ? context.sfShared
                                    : context.sfMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                color: isToday
                                    ? context.sfShared
                                    : context.sfText,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: entries.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 9),
                                child: Text(
                                  'Rien de prévu',
                                  style: TextStyle(
                                    color: context.sfMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final entry in entries.take(
                                    _visiblePerDay,
                                  ))
                                    _EntryPill(entry: entry),
                                  if (entries.length > _visiblePerDay)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4,
                                        top: 2,
                                      ),
                                      child: Text(
                                        '+ ${entries.length - _visiblePerDay} autre${entries.length - _visiblePerDay > 1 ? 's' : ''}',
                                        style: TextStyle(
                                          color: context.sfMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EntryPill extends StatelessWidget {
  const _EntryPill({required this.entry});

  final AgendaCalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = entry.kind.color(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.sfIsDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(entry.kind.icon, size: 14, color: color),
          const SizedBox(width: 6),
          if (entry.time case final time?) ...[
            Text(
              time,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.sfText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (entry.isCompany)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.work_outline, size: 13, color: context.sfMuted),
            ),
        ],
      ),
    );
  }
}

/// Mois : grille compacte, un point de couleur par catégorie présente.
class _MonthPage extends StatelessWidget {
  const _MonthPage({
    required this.firstDay,
    required this.today,
    required this.byDay,
    required this.onOpenDay,
  });

  static const _weekdayInitials = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  final DateTime firstDay;
  final DateTime today;
  final Map<DateTime, List<AgendaCalendarEntry>> byDay;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final gridStart = StudyFlowDates.mondayOf(firstDay);
    final lastDay = DateTime(firstDay.year, firstDay.month + 1, 0);
    final weeks = (lastDay.difference(gridStart).inDays ~/ 7) + 1;
    final monthEntries = byDay.entries
        .where(
          (x) => x.key.year == firstDay.year && x.key.month == firstDay.month,
        )
        .expand((x) => x.value)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 112),
      children: [
        Row(
          children: [
            for (final initial in _weekdayInitials)
              Expanded(
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: context.sfMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var week = 0; week < weeks; week++)
          Row(
            children: [
              for (var weekday = 0; weekday < 7; weekday++)
                Expanded(
                  child: _MonthCell(
                    day: StudyFlowDates.addDays(gridStart, week * 7 + weekday),
                    inMonth:
                        StudyFlowDates.addDays(
                          gridStart,
                          week * 7 + weekday,
                        ).month ==
                        firstDay.month,
                    today: today,
                    entries:
                        byDay[StudyFlowDates.addDays(
                          gridStart,
                          week * 7 + weekday,
                        )] ??
                        const [],
                    onTap: onOpenDay,
                  ),
                ),
            ],
          ),
        const SizedBox(height: 14),
        _MonthSummary(entries: monthEntries),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.day,
    required this.inMonth,
    required this.today,
    required this.entries,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final DateTime today;
  final List<AgendaCalendarEntry> entries;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(day, today);
    final kinds = {for (final entry in entries) entry.kind}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: entries.isEmpty || !inMonth
            ? Colors.transparent
            : context.sfCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('agenda-month-day-${day.month}-${day.day}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => onTap(day),
          child: Opacity(
            opacity: inMonth ? 1 : 0.35,
            child: SizedBox(
              height: 58,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? context.sfAccent : null,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: isToday ? context.sfOnAccent : context.sfText,
                        fontSize: 14,
                        fontWeight: isToday || entries.isNotEmpty
                            ? FontWeight.w900
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final kind in kinds)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: kind.color(context),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.entries});

  final List<AgendaCalendarEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const ProtoMutedText('Rien de prévu ce mois-ci.');
    }

    return ProtoCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ce mois-ci',
            style: TextStyle(
              color: context.sfText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final kind in AgendaEntryKind.values)
            if (entries.where((x) => x.kind == kind).length case final count
                when count > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(kind.icon, size: 16, color: kind.color(context)),
                    const SizedBox(width: 8),
                    Text(
                      '$count ${kind.singular}${count > 1 ? 's' : ''}',
                      style: TextStyle(color: context.sfText),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 4),
          const ProtoMutedText('Touche un jour pour voir le détail.'),
        ],
      ),
    );
  }
}
