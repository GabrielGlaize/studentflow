import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/agenda/presentation/homework_form_page.dart';
import 'package:studyflow_app/features/schedule/domain/course_models.dart';
import 'package:studyflow_app/features/schedule/presentation/course_form_page.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late DateTime _weekStart;
  late DateTime _selectedDay;
  bool _showWholeWeek = false;
  Future<List<CourseItem>>? _coursesFuture;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _weekStart = StudyFlowDates.mondayOf(today);
    _selectedDay = DateTime(today.year, today.month, today.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coursesFuture ??= _loadCourses();
  }

  @override
  Widget build(BuildContext context) {
    final isSelectedToday = _sameDate(_selectedDay, DateTime.now());
    final hasClass =
        AppScope.of(context).sessionController.session?.user.schoolClassId !=
        null;

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              ProtoScreenTitle(
                title: 'Planning',
                subtitle: _weekLabel,
                trailing: OutlinedButton(
                  onPressed: isSelectedToday ? null : _goToCurrentWeek,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('Aujourd’hui'),
                ),
              ),
              _WeekPicker(
                weekStart: _weekStart,
                selectedDay: _selectedDay,
                onSelectDay: _selectDay,
                onPrevious: () => _moveWeek(-1),
                onNext: () => _moveWeek(1),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 2),
                child: _PlanningViewSwitch(
                  showWholeWeek: _showWholeWeek,
                  onChanged: (value) => setState(() => _showWholeWeek = value),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CourseItem>>(
                  future: _coursesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const ProtoPageLoader(label: 'Emploi du temps');
                    }

                    if (snapshot.hasError) {
                      return _ScheduleError(
                        hasClass: hasClass,
                        onRetry: _refresh,
                      );
                    }

                    final courses = snapshot.requireData;
                    if (courses.isEmpty) {
                      return _EmptySchedule(
                        hasClass: hasClass,
                        onRefresh: _refresh,
                      );
                    }

                    final visibleCourses = _showWholeWeek
                        ? courses
                        : courses
                              .where(
                                (course) => _sameDate(course.day, _selectedDay),
                              )
                              .toList(growable: false);
                    final grouped = _groupByDay(visibleCourses);
                    final total = visibleCourses.length;

                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 118),
                        children: [
                          _DaySummary(
                            courseCount: total,
                            showWholeWeek: _showWholeWeek,
                          ),
                          const SizedBox(height: 12),
                          if (visibleCourses.isEmpty)
                            ProtoStateCard(
                              icon: Icons.event_busy_outlined,
                              title: 'Aucun cours',
                              message: _showWholeWeek
                                  ? 'La semaine est vide pour le moment.'
                                  : 'Change de jour ou ajoute le cours manquant.',
                              compact: true,
                            )
                          else
                            ...grouped.entries.map(
                              (entry) => _DayTimeline(
                                day: entry.key,
                                courses: entry.value,
                                onEditCourse: _openCourseForm,
                                onDeleteCourse: _deleteCourse,
                                onOpenHistory: _openCourseHistory,
                                onDuplicateCourse: _duplicateCourse,
                                onAddHomework: _addHomework,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: hasClass
                  ? FloatingActionButton.extended(
                      key: const ValueKey('add-course-button'),
                      heroTag: 'add-course',
                      backgroundColor: context.sfAccent,
                      foregroundColor: context.sfOnAccent,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      onPressed: () => _openCourseForm(),
                      icon: const _AddCourseIcon(),
                      label: const Text('Ajouter un cours'),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<CourseItem>> _loadCourses() async {
    final appScope = AppScope.of(context);
    if (appScope.sessionController.session?.user.schoolClassId == null) {
      return const [];
    }

    final accessToken = await appScope.sessionController.accessTokenForApi();
    final weekEnd = StudyFlowDates.addDays(_weekStart, 6);

    return appScope.courseRepository.listCourses(
      from: _weekStart,
      to: weekEnd,
      accessToken: accessToken,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _coursesFuture = _loadCourses();
    });
    await _coursesFuture;
  }

  void _moveWeek(int direction) {
    final nextWeekStart = StudyFlowDates.addDays(_weekStart, direction * 7);
    setState(() {
      _weekStart = nextWeekStart;
      _selectedDay = nextWeekStart;
      _coursesFuture = _loadCourses();
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = day;
    });
  }

  void _goToCurrentWeek() {
    final today = DateTime.now();
    setState(() {
      _weekStart = StudyFlowDates.mondayOf(today);
      _selectedDay = DateTime(today.year, today.month, today.day);
      _coursesFuture = _loadCourses();
    });
  }

  Future<void> _openCourseForm([CourseItem? course]) async {
    final knownRooms = await _knownRooms();
    if (!mounted) return;
    final saved = await CourseFormPage.open(
      context,
      initialDay: _selectedDay,
      course: course,
      knownRooms: knownRooms,
    );

    if (saved == true && mounted) await _refresh();
  }

  /// Duplique un cours sur le créneau suivant du même jour (pause de 15 min),
  /// le cas le plus fréquent quand une matière enchaîne plusieurs créneaux.
  Future<void> _duplicateCourse(CourseItem course) async {
    final start = course.endDateTime.add(const Duration(minutes: 15));
    final end = start.add(course.endDateTime.difference(course.startDateTime));
    final sameDay = end.day == course.day.day;
    final knownRooms = await _knownRooms();
    if (!mounted) return;
    final saved = await CourseFormPage.open(
      context,
      initialDay: course.day,
      knownRooms: knownRooms,
      template: course.toFormData().copyWith(
        startsAt: sameDay ? StudyFlowFormat.timeOf(start) : course.startsAt,
        endsAt: sameDay ? StudyFlowFormat.timeOf(end) : course.endsAt,
        day: sameDay ? course.day : StudyFlowDates.addDays(course.day, 7),
      ),
    );

    if (saved == true && mounted) await _refresh();
  }

  Future<void> _addHomework(CourseItem course) async {
    final saved = await HomeworkFormPage.open(context, initialCourse: course);
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Devoir ajouté à l’agenda de la classe.'),
          ),
        );
    }
  }

  Future<List<String>> _knownRooms() async {
    try {
      final courses = await _coursesFuture;
      return [...?courses?.map((course) => course.room)];
    } on Exception {
      return const [];
    }
  }

  Future<void> _deleteCourse(CourseItem course) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce cours ?'),
        content: Text(
          '“${course.subjectName}” sera retiré de l’emploi du temps.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.courseRepository.deleteCourse(
      courseId: course.id,
      accessToken: accessToken,
    );

    if (mounted) await _refresh();
  }

  Future<void> _openCourseHistory(CourseItem course) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _CourseHistorySheet(
        course: course,
        onRestored: () async {
          Navigator.pop(context);
          await _refresh();
        },
      ),
    );
  }

  Map<DateTime, List<CourseItem>> _groupByDay(List<CourseItem> courses) {
    final grouped = <DateTime, List<CourseItem>>{};
    for (final course in courses) {
      final day = DateTime(course.day.year, course.day.month, course.day.day);
      grouped.putIfAbsent(day, () => []).add(course);
    }

    for (final items in grouped.values) {
      items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    }

    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  String get _weekLabel {
    final end = StudyFlowDates.addDays(_weekStart, 6);
    return 'Semaine du ${_formatDay(_weekStart)} au ${_formatDay(end)}';
  }
}

class _AddCourseIcon extends StatelessWidget {
  const _AddCourseIcon();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.calendar_today_outlined, size: 20),
        Positioned(right: -7, top: -7, child: Icon(Icons.add_circle, size: 15)),
      ],
    );
  }
}

class _WeekPicker extends StatelessWidget {
  const _WeekPicker({
    required this.weekStart,
    required this.selectedDay,
    required this.onSelectDay,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      5,
      (index) => StudyFlowDates.addDays(weekStart, index),
    );
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: context.sfCard,
        border: Border.symmetric(horizontal: BorderSide(color: context.sfLine)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            color: context.sfChevron,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days.map((day) {
                final isToday = _sameDate(day, today);
                final isSelected = _sameDate(day, selectedDay);

                return _DayPill(
                  day: day,
                  isActive: isSelected,
                  isToday: isToday,
                  onTap: () => onSelectDay(day),
                );
              }).toList(),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            color: context.sfChevron,
          ),
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.day,
    required this.isActive,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final bool isActive;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final names = ['LUN', 'MAR', 'MER', 'JEU', 'VEN'];
    final label = names[(day.weekday - 1).clamp(0, 4)];
    final inactiveText = context.sfText;
    final inactiveMuted = context.sfMuted;
    final activeText = context.sfOnAccent;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 54,
        height: 62,
        decoration: BoxDecoration(
          color: isActive ? context.sfAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isToday && !isActive
              ? Border.all(color: context.sfAccent, width: 1.4)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeText : inactiveMuted,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${day.day}',
              style: TextStyle(
                color: isActive ? activeText : inactiveText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isToday
                    ? (isActive ? activeText : context.sfAccent)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.courseCount, required this.showWholeWeek});

  final int courseCount;
  final bool showWholeWeek;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ProtoSectionHeading(
            overline: 'Planning partagé',
            title: showWholeWeek
                ? '$courseCount cours cette semaine'
                : '$courseCount cours ce jour',
          ),
        ),
        const ProtoVisibilityChip(shared: true),
      ],
    );
  }
}

class _PlanningViewSwitch extends StatelessWidget {
  const _PlanningViewSwitch({
    required this.showWholeWeek,
    required this.onChanged,
  });

  final bool showWholeWeek;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('Jour')),
        ButtonSegment(value: true, label: Text('Semaine')),
      ],
      selected: {showWholeWeek},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
    );
  }
}

class _DayTimeline extends StatelessWidget {
  const _DayTimeline({
    required this.day,
    required this.courses,
    required this.onEditCourse,
    required this.onDeleteCourse,
    required this.onOpenHistory,
    required this.onDuplicateCourse,
    required this.onAddHomework,
  });

  final DateTime day;
  final List<CourseItem> courses;
  final ValueChanged<CourseItem> onEditCourse;
  final ValueChanged<CourseItem> onDeleteCourse;
  final ValueChanged<CourseItem> onOpenHistory;
  final ValueChanged<CourseItem> onDuplicateCourse;
  final ValueChanged<CourseItem> onAddHomework;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              _weekdayLabel(day),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.sfText,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
          ),
          ...courses.asMap().entries.map(
            (entry) => _TimelineCourseCard(
              course: entry.value,
              paletteIndex: entry.key,
              onEdit: () => onEditCourse(entry.value),
              onDelete: () => onDeleteCourse(entry.value),
              onOpenHistory: () => onOpenHistory(entry.value),
              onDuplicate: () => onDuplicateCourse(entry.value),
              onAddHomework: () => onAddHomework(entry.value),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCourseCard extends StatelessWidget {
  const _TimelineCourseCard({
    required this.course,
    required this.paletteIndex,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenHistory,
    required this.onDuplicate,
    required this.onAddHomework,
  });

  final CourseItem course;
  final int paletteIndex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenHistory;
  final VoidCallback onDuplicate;
  final VoidCallback onAddHomework;

  @override
  Widget build(BuildContext context) {
    final isDark = context.sfIsDark;
    final accent = course.isCancelled
        ? AppColors.rose
        : isDark
        ? _darkAccentColor
        : _accentColor;
    final cardBackground = course.isCancelled
        ? AppColors.roseSoft
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    course.startsAt,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.sfText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    course.endsAt,
                    style: TextStyle(fontSize: 12, color: context.sfMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ProtoCard(
              onTap: onEdit,
              padding: const EdgeInsets.fromLTRB(13, 13, 8, 13),
              borderColor: course.isCancelled
                  ? const Color(0xFFE3CDD2)
                  : AppColors.line,
              backgroundColor: cardBackground,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  course.isCancelled ? 'ANNULÉ' : 'COURS',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              PopupMenuButton<_CourseAction>(
                                tooltip: 'Actions cours',
                                icon: const Icon(Icons.more_horiz),
                                color: context.sfCard,
                                onSelected: (action) {
                                  switch (action) {
                                    case _CourseAction.edit:
                                      onEdit();
                                    case _CourseAction.addHomework:
                                      onAddHomework();
                                    case _CourseAction.duplicate:
                                      onDuplicate();
                                    case _CourseAction.history:
                                      onOpenHistory();
                                    case _CourseAction.delete:
                                      onDelete();
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: _CourseAction.addHomework,
                                    child: ListTile(
                                      leading: Icon(Icons.assignment_add),
                                      title: Text('Ajouter un devoir'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _CourseAction.edit,
                                    child: ListTile(
                                      leading: Icon(Icons.edit_outlined),
                                      title: Text('Modifier'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _CourseAction.duplicate,
                                    child: ListTile(
                                      leading: Icon(Icons.copy_all_outlined),
                                      title: Text('Dupliquer'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _CourseAction.history,
                                    child: ListTile(
                                      leading: Icon(Icons.history_outlined),
                                      title: Text('Historique'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _CourseAction.delete,
                                    child: ListTile(
                                      leading: Icon(Icons.delete_outline),
                                      title: Text('Supprimer'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            course.subjectName,
                            style: TextStyle(
                              color: context.sfText,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              decoration: course.isCancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 11,
                            runSpacing: 6,
                            children: [
                              _TinyDetail(
                                icon: Icons.meeting_room_outlined,
                                text: 'Salle ${course.room}',
                              ),
                              if (course.teacherName != null)
                                _TinyDetail(
                                  icon: Icons.person_outline,
                                  text: course.teacherName!,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color get _accentColor {
    final colors = [AppColors.petrol, AppColors.green, const Color(0xFF4F7891)];
    return colors[paletteIndex % colors.length];
  }

  Color get _darkAccentColor {
    final colors = [AppColors.sky, AppColors.mint, const Color(0xFF9ED7E9)];
    return colors[paletteIndex % colors.length];
  }
}

enum _CourseAction { addHomework, edit, duplicate, history, delete }

class _TinyDetail extends StatelessWidget {
  const _TinyDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.sfMuted),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: context.sfMuted, fontSize: 13)),
      ],
    );
  }
}

class _CourseHistorySheet extends StatefulWidget {
  const _CourseHistorySheet({required this.course, required this.onRestored});

  final CourseItem course;
  final Future<void> Function() onRestored;

  @override
  State<_CourseHistorySheet> createState() => _CourseHistorySheetState();
}

class _CourseHistorySheetState extends State<_CourseHistorySheet> {
  Future<List<CourseRevisionItem>>? _future;
  bool _isRestoring = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: FutureBuilder<List<CourseRevisionItem>>(
        future: _future,
        builder: (context, snapshot) {
          final revisions = snapshot.data ?? const <CourseRevisionItem>[];

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  ProtoIconBox(icon: Icons.history_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: ProtoSectionHeading(
                      overline: 'Autosuffisance',
                      title: 'Historique du cours',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ProtoMutedText(
                'Cours : ${widget.course.subjectName}. Les corrections restent visibles pour comprendre ce qui a changé.',
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator()
              else if (revisions.isEmpty)
                const ProtoStateCard(
                  icon: Icons.history_toggle_off_outlined,
                  title: 'Aucun historique',
                  message: 'Les modifications apparaîtront ici.',
                  compact: true,
                )
              else
                ...revisions.map(_CourseRevisionTile.new),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isRestoring
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isRestoring ? null : _restoreLatest,
                      icon: const Icon(Icons.restore_outlined, size: 18),
                      label: Text(
                        _isRestoring ? 'Restauration...' : 'Version précédente',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<CourseRevisionItem>> _load() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    return appScope.courseRepository.listCourseRevisions(
      courseId: widget.course.id,
      accessToken: accessToken,
    );
  }

  Future<void> _restoreLatest() async {
    setState(() => _isRestoring = true);
    final appScope = AppScope.of(context);

    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.courseRepository.restoreLatestCourse(
        courseId: widget.course.id,
        accessToken: accessToken,
      );
      await widget.onRestored();
    } on Exception catch (error) {
      // Par exemple : rien à annuler, ou l'ancien créneau est déjà occupé.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }
}

class _CourseRevisionTile extends StatelessWidget {
  const _CourseRevisionTile(this.revision);

  final CourseRevisionItem revision;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.only(top: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          const ProtoIconBox(icon: Icons.edit_note_outlined, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_revisionActionLabel(revision.action)} · v${revision.version}',
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                ProtoMutedText(
                  '${revision.authorName} · ${_dateTimeLabel(revision.createdAt)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule({required this.hasClass, required this.onRefresh});

  final bool hasClass;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 90, 24, 140),
        children: [
          ProtoStateCard(
            icon: Icons.calendar_month_outlined,
            title: hasClass ? 'Semaine vide' : 'Pas encore de classe',
            message: hasClass
                ? 'Aucun cours prévu sur cette semaine. Tu peux en ajouter un si la classe ne l’a pas encore fait.'
                : 'Rejoins une classe ou crée la tienne depuis le profil pour afficher un planning partagé.',
          ),
        ],
      ),
    );
  }
}

class _ScheduleError extends StatelessWidget {
  const _ScheduleError({required this.hasClass, required this.onRetry});

  final bool hasClass;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ProtoStateCard(
      icon: Icons.cloud_off_outlined,
      title: hasClass ? 'Emploi du temps indisponible' : 'Pas encore de classe',
      message: hasClass
          ? 'Impossible de charger les cours de cette semaine.'
          : 'Rejoins une classe ou crée la tienne depuis le profil pour accéder aux cours partagés.',
      actionLabel: 'Réessayer',
      onAction: onRetry,
    );
  }
}

String _formatDay(DateTime day) {
  return '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';
}

bool _sameDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String _dateTimeLabel(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month à $hour:$minute';
}

String _revisionActionLabel(String action) {
  return switch (action) {
    'Created' => 'Création',
    'Updated' => 'Modification',
    'Deleted' => 'Suppression',
    'Restored' => 'Restauration',
    _ => action,
  };
}

String _weekdayLabel(DateTime day) {
  const names = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  return '${names[day.weekday - 1]} ${_formatDay(day)}';
}
