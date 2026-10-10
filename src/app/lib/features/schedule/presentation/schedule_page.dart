import 'dart:async';

import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/agenda/presentation/homework_form_page.dart';
import 'package:studyflow_app/features/exams/domain/exam_models.dart';
import 'package:studyflow_app/features/exams/presentation/exams_page.dart';
import 'package:studyflow_app/features/schedule/domain/course_models.dart';
import 'package:studyflow_app/features/schedule/presentation/course_form_page.dart';

/// Planning partagé de la classe.
///
/// Vue jour : on balaie avec le pouce d'un jour de cours à l'autre (lundi à
/// vendredi). Vue semaine : toute la semaine d'un coup d'œil, les jours sans
/// cours regroupés sur une ligne ; on balaie d'une semaine à l'autre.
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  /// Les pages sont numérotées autour de la semaine actuelle.
  static const _origin = 5000;
  static const _weekdays = 5;

  late final DateTime _anchorMonday;
  late DateTime _selectedDay;
  bool _showWholeWeek = false;
  late PageController _dayController;
  late PageController _weekController;
  final Map<DateTime, Future<List<CourseItem>>> _weeks = {};
  bool _hasClass = false;

  /// Épreuves de partiels, rangées par jour, affichées avec les cours.
  Map<DateTime, List<_ExamSlot>> _exams = const {};
  bool _examsRequested = false;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _anchorMonday = StudyFlowDates.mondayOf(today);
    // Le week-end, on montre directement le lundi qui arrive.
    _selectedDay = today.weekday > DateTime.friday
        ? StudyFlowDates.addDays(_anchorMonday, 7)
        : today;
    _dayController = PageController(initialPage: _dayIndexOf(_selectedDay));
    _weekController = PageController(initialPage: _weekIndexOf(_selectedDay));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hasClass =
        AppScope.of(context).sessionController.session?.user.schoolClassId !=
        null;
    if (!_examsRequested) {
      _examsRequested = true;
      unawaited(_loadExams());
    }
  }

  Future<void> _loadExams() async {
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final sessions = await appScope.examRepository.listSessions(
        accessToken: accessToken,
      );
      final byDay = <DateTime, List<_ExamSlot>>{};
      for (final session in sessions) {
        for (final subject in session.subjects) {
          final day = subject.examDay;
          if (day == null) continue;
          byDay
              .putIfAbsent(DateUtils.dateOnly(day), () => [])
              .add(_ExamSlot(session: session, subject: subject));
        }
      }
      for (final slots in byDay.values) {
        slots.sort(
          (a, b) =>
              (a.subject.startsAt ?? '').compareTo(b.subject.startsAt ?? ''),
        );
      }
      if (mounted) setState(() => _exams = byDay);
    } on Exception {
      // Facultatif : sans partiels, le planning reste utilisable.
    }
  }

  List<_ExamSlot> _examsOn(DateTime day) =>
      _exams[DateUtils.dateOnly(day)] ?? const [];

  Future<void> _openExam(_ExamSlot slot) async {
    await ExamsPage.open(context, sessionId: slot.session.id);
    if (mounted) unawaited(_loadExams());
  }

  @override
  void dispose() {
    _dayController.dispose();
    _weekController.dispose();
    super.dispose();
  }

  DateTime get _weekStart => StudyFlowDates.mondayOf(_selectedDay);

  int _weekIndexOf(DateTime day) =>
      _origin +
      (StudyFlowDates.mondayOf(day).difference(_anchorMonday).inDays / 7)
          .round();

  int _dayIndexOf(DateTime day) {
    final weekday = (day.weekday - 1).clamp(0, _weekdays - 1);
    return (_weekIndexOf(day) - _origin) * _weekdays + weekday + _origin;
  }

  DateTime _dayAt(int index) {
    final offset = index - _origin;
    final weeks = (offset / _weekdays).floor();
    final weekday = offset - weeks * _weekdays;
    return StudyFlowDates.addDays(_anchorMonday, weeks * 7 + weekday);
  }

  DateTime _weekAt(int index) =>
      StudyFlowDates.addDays(_anchorMonday, (index - _origin) * 7);

  Future<List<CourseItem>> _coursesOfWeek(DateTime monday) {
    return _weeks.putIfAbsent(monday, () => _loadWeek(monday));
  }

  Future<List<CourseItem>> _loadWeek(DateTime monday) async {
    final appScope = AppScope.of(context);
    if (appScope.sessionController.session?.user.schoolClassId == null) {
      // L'adhésion a pu être validée depuis un autre appareil.
      await appScope.sessionController.reloadUser();
      if (appScope.sessionController.session?.user.schoolClassId == null) {
        return const [];
      }
      if (mounted && !_hasClass) setState(() => _hasClass = true);
    }

    final accessToken = await appScope.sessionController.accessTokenForApi();
    final courses = await appScope.courseRepository.listCourses(
      from: monday,
      to: StudyFlowDates.addDays(monday, 6),
      accessToken: accessToken,
    );
    return [...courses]..sort(_byStart);
  }

  Future<void> _refresh() async {
    setState(_weeks.clear);
    unawaited(_loadExams());
    await _coursesOfWeek(_weekStart);
    if (mounted) AppScope.of(context).reminderSync.requestSync();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final atToday = _showWholeWeek
        ? DateUtils.isSameDay(_weekStart, StudyFlowDates.mondayOf(today))
        : DateUtils.isSameDay(_selectedDay, today);

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              ProtoScreenTitle(
                title: 'Planning',
                subtitle: _weekLabel,
                trailing: OutlinedButton(
                  key: const ValueKey('planning-today-button'),
                  onPressed: atToday ? null : _goToToday,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(_showWholeWeek ? 'Cette semaine' : 'Aujourd’hui'),
                ),
              ),
              FutureBuilder<List<CourseItem>>(
                future: _coursesOfWeek(_weekStart),
                builder: (context, snapshot) => _WeekStrip(
                  weekStart: _weekStart,
                  selectedDay: _showWholeWeek ? null : _selectedDay,
                  courses: snapshot.data ?? const [],
                  onSelectDay: _openDay,
                  onPrevious: () => _moveWeek(-1),
                  onNext: () => _moveWeek(1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                child: _PlanningViewSwitch(
                  showWholeWeek: _showWholeWeek,
                  onChanged: _setWholeWeek,
                ),
              ),
              Expanded(
                child: !_hasClass
                    ? _EmptySchedule(hasClass: false, onRefresh: _refresh)
                    : _showWholeWeek
                    ? PageView.builder(
                        key: const ValueKey('week-pager'),
                        controller: _weekController,
                        onPageChanged: (index) => setState(() {
                          final monday = _weekAt(index);
                          _selectedDay = StudyFlowDates.addDays(
                            monday,
                            (_selectedDay.weekday - 1).clamp(0, 4),
                          );
                        }),
                        itemBuilder: (context, index) =>
                            _buildWeekPage(_weekAt(index)),
                      )
                    : PageView.builder(
                        key: const ValueKey('day-pager'),
                        controller: _dayController,
                        onPageChanged: (index) =>
                            setState(() => _selectedDay = _dayAt(index)),
                        itemBuilder: (context, index) =>
                            _buildDayPage(_dayAt(index)),
                      ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: _hasClass
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

  Widget _buildDayPage(DateTime day) {
    return FutureBuilder<List<CourseItem>>(
      future: _coursesOfWeek(StudyFlowDates.mondayOf(day)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ProtoPageLoader(label: 'Emploi du temps');
        }
        if (snapshot.hasError) {
          return _ScheduleError(hasClass: _hasClass, onRetry: _refresh);
        }

        final courses = snapshot.requireData
            .where((course) => DateUtils.isSameDay(course.day, day))
            .toList();
        final active = courses.where((x) => !x.isCancelled).toList();
        final exams = _examsOn(day);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 118),
            children: [
              Row(
                children: [
                  Expanded(
                    child: ProtoSectionHeading(
                      overline: StudyFlowFormat.longDay(day),
                      title: courses.isEmpty && exams.isNotEmpty
                          ? '${exams.length} épreuve${exams.length > 1 ? 's' : ''} de partiel'
                          : courses.isEmpty
                          ? 'Pas de cours'
                          : active.isEmpty
                          ? 'Cours annulés'
                          : '${active.length} cours · ${active.first.startsAt}–${active.last.endsAt}',
                    ),
                  ),
                  const ProtoVisibilityChip(shared: true),
                ],
              ),
              const SizedBox(height: 12),
              if (courses.isEmpty && exams.isEmpty)
                const ProtoStateCard(
                  icon: Icons.event_busy_outlined,
                  title: 'Journée libre',
                  message:
                      'Balaie l’écran pour passer au jour suivant, ou ajoute le cours manquant.',
                  compact: true,
                )
              else
                _DayTimeline(
                  day: day,
                  courses: courses,
                  exams: exams,
                  onOpenExam: _openExam,
                  showHeader: false,
                  onEditCourse: _openCourseForm,
                  onDeleteCourse: _deleteCourse,
                  onOpenHistory: _openCourseHistory,
                  onDuplicateCourse: _duplicateCourse,
                  onAddHomework: _addHomework,
                  onToggleCancelled: _toggleCancelled,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeekPage(DateTime monday) {
    return FutureBuilder<List<CourseItem>>(
      future: _coursesOfWeek(monday),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ProtoPageLoader(label: 'Emploi du temps');
        }
        if (snapshot.hasError) {
          return _ScheduleError(hasClass: _hasClass, onRetry: _refresh);
        }

        final courses = snapshot.requireData;
        final days = List.generate(7, (i) => StudyFlowDates.addDays(monday, i));
        final byDay = {
          for (final day in days)
            day: courses
                .where((course) => DateUtils.isSameDay(course.day, day))
                .toList(),
        };
        final courseDays = days
            .where((day) => byDay[day]!.isNotEmpty || _examsOn(day).isNotEmpty)
            .toList();
        final freeWeekdays = days
            .take(_weekdays)
            .where((day) => byDay[day]!.isEmpty && _examsOn(day).isEmpty)
            .toList();
        final count = courses.where((x) => !x.isCancelled).length;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 118),
            children: [
              Row(
                children: [
                  Expanded(
                    child: ProtoSectionHeading(
                      overline: 'Planning de la classe',
                      title: courseDays.isEmpty
                          ? 'Aucun cours cette semaine'
                          : _weekSummary(
                              courses: count,
                              exams: days
                                  .map((day) => _examsOn(day).length)
                                  .fold(0, (sum, x) => sum + x),
                              days: courseDays.length,
                            ),
                    ),
                  ),
                  const ProtoVisibilityChip(shared: true),
                ],
              ),
              const SizedBox(height: 12),
              if (courseDays.isEmpty)
                const ProtoStateCard(
                  icon: Icons.event_busy_outlined,
                  title: 'Semaine vide',
                  message:
                      'Balaie pour voir la semaine suivante, ou ajoute les cours de celle-ci.',
                  compact: true,
                )
              else
                for (final day in courseDays)
                  _DayTimeline(
                    day: day,
                    courses: byDay[day]!,
                    exams: _examsOn(day),
                    onOpenExam: _openExam,
                    compact: true,
                    onOpenDay: () => _openDay(day),
                    onEditCourse: _openCourseForm,
                    onDeleteCourse: _deleteCourse,
                    onOpenHistory: _openCourseHistory,
                    onDuplicateCourse: _duplicateCourse,
                    onAddHomework: _addHomework,
                    onToggleCancelled: _toggleCancelled,
                  ),
              if (courseDays.isNotEmpty && freeWeekdays.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.free_breakfast_outlined,
                        size: 18,
                        color: context.sfMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ProtoMutedText(
                          'Pas de cours ${_joinDays(freeWeekdays)}.',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// « 12 cours sur 4 jours », « 3 partiels », « 8 cours · 2 partiels ».
  String _weekSummary({
    required int courses,
    required int exams,
    required int days,
  }) {
    final examLabel = '$exams partiel${exams > 1 ? 's' : ''}';
    if (courses == 0) return examLabel;
    final courseLabel = '$courses cours sur $days jour${days > 1 ? 's' : ''}';
    return exams == 0 ? courseLabel : '$courses cours · $examLabel';
  }

  String _joinDays(List<DateTime> days) {
    final names = days
        .map(
          (day) => StudyFlowFormat.longDay(day).split(' ').first.toLowerCase(),
        )
        .toList();
    if (names.length == 1) return names.single;
    return '${names.take(names.length - 1).join(', ')} et ${names.last}';
  }

  void _setWholeWeek(bool value) {
    if (value == _showWholeWeek) return;
    setState(() {
      _showWholeWeek = value;
      // Les vues ne sont pas montées en même temps : on repart du jour choisi.
      _dayController.dispose();
      _weekController.dispose();
      _dayController = PageController(initialPage: _dayIndexOf(_selectedDay));
      _weekController = PageController(initialPage: _weekIndexOf(_selectedDay));
    });
  }

  /// Touche d'un jour : vue jour sur ce jour.
  void _openDay(DateTime day) {
    if (day.weekday > DateTime.friday) {
      _setWholeWeek(true);
      return;
    }
    if (_showWholeWeek) {
      setState(() => _selectedDay = day);
      _setWholeWeek(false);
      return;
    }
    _dayController.animateToPage(
      _dayIndexOf(day),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _moveWeek(int direction) {
    if (_showWholeWeek) {
      _weekController.animateToPage(
        _weekIndexOf(_selectedDay) + direction,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    // Même jour de la semaine, une semaine plus tôt ou plus tard.
    _dayController.jumpToPage(
      _dayIndexOf(_selectedDay) + direction * _weekdays,
    );
  }

  void _goToToday() {
    final today = DateUtils.dateOnly(DateTime.now());
    final target = today.weekday > DateTime.friday
        ? StudyFlowDates.addDays(_anchorMonday, 7)
        : today;
    if (_showWholeWeek) {
      _weekController.jumpToPage(_weekIndexOf(today));
    } else {
      _dayController.jumpToPage(_dayIndexOf(target));
    }
  }

  Future<void> _openCourseForm([CourseItem? course]) async {
    final saved = await CourseFormPage.open(
      context,
      initialDay: _selectedDay,
      course: course,
    );

    if (saved == true && mounted) await _refresh();
  }

  /// Duplique un cours sur le créneau suivant du même jour (pause de 15 min),
  /// le cas le plus fréquent quand une matière enchaîne plusieurs créneaux.
  Future<void> _duplicateCourse(CourseItem course) async {
    final start = course.endDateTime.add(const Duration(minutes: 15));
    final end = start.add(course.endDateTime.difference(course.startDateTime));
    final sameDay = end.day == course.day.day;
    final saved = await CourseFormPage.open(
      context,
      initialDay: course.day,
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
      AppScope.of(context).reminderSync.requestSync();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Devoir ajouté à l’agenda de la classe.'),
          ),
        );
    }
  }

  /// Annule (ou rétablit) un cours. À l'annulation, propose d'annuler aussi
  /// les autres cours de la journée pas encore terminés : l'intervenant absent
  /// assure souvent toute la journée. La réponse par défaut est « Oui ».
  Future<void> _toggleCancelled(CourseItem course) async {
    final messenger = ScaffoldMessenger.of(context);

    if (course.isCancelled) {
      await _setCancelled({course.id}, course.day, cancelled: false);
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Cours rétabli.')));
      return;
    }

    final now = DateTime.now();
    final sameDay = (await _coursesOfWeek(StudyFlowDates.mondayOf(course.day)))
        .where(
          (other) =>
              other.id != course.id &&
              !other.isCancelled &&
              DateUtils.isSameDay(other.day, course.day) &&
              other.endDateTime.isAfter(now),
        )
        .toList();
    if (!mounted) return;

    final ids = {course.id};
    if (sameDay.isNotEmpty) {
      final alsoOthers = await showDialog<bool>(
        context: context,
        builder: (context) =>
            _CancelCourseDialog(course: course, others: sameDay),
      );
      if (alsoOthers == null || !mounted) return;
      if (alsoOthers) ids.addAll(sameDay.map((other) => other.id));
    }

    final done = await _setCancelled(ids, course.day, cancelled: true);
    if (!done || !mounted) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ids.length == 1
                ? '${course.subjectName} annulé pour la classe.'
                : '${ids.length} cours annulés pour la journée.',
          ),
          action: SnackBarAction(
            label: 'Rétablir',
            onPressed: () => _setCancelled(ids, course.day, cancelled: false),
          ),
        ),
      );
  }

  /// Relit les cours du jour avant de les modifier : le serveur refuse une
  /// version périmée (après une annulation tout juste faite, par exemple).
  Future<bool> _setCancelled(
    Set<String> courseIds,
    DateTime day, {
    required bool cancelled,
  }) async {
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final fresh = await appScope.courseRepository.listCourses(
        from: day,
        to: day,
        accessToken: accessToken,
      );
      for (final course in fresh.where((x) => courseIds.contains(x.id))) {
        if (course.isCancelled == cancelled) continue;
        await appScope.courseRepository.updateCourse(
          courseId: course.id,
          data: course.toFormData().copyWith(isCancelled: cancelled),
          accessToken: accessToken,
        );
      }
      return true;
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return false;
    } finally {
      if (mounted) await _refresh();
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

  String get _weekLabel {
    final end = StudyFlowDates.addDays(_weekStart, 6);
    return 'Semaine du ${_formatDay(_weekStart)} au ${_formatDay(end)}';
  }
}

int _byStart(CourseItem a, CourseItem b) {
  final day = a.day.compareTo(b.day);
  return day != 0 ? day : a.startsAt.compareTo(b.startsAt);
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

/// Bandeau des jours. En vue jour, le jour affiché est rempli ; en vue
/// semaine, aucun jour n'est mis en avant. Les points indiquent les cours.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.weekStart,
    required this.selectedDay,
    required this.courses,
    required this.onSelectDay,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime weekStart;
  final DateTime? selectedDay;
  final List<CourseItem> courses;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final weekend = [5, 6]
        .map((i) => StudyFlowDates.addDays(weekStart, i))
        .where((day) => courses.any((c) => DateUtils.isSameDay(c.day, day)));
    final days = [
      for (var i = 0; i < 5; i++) StudyFlowDates.addDays(weekStart, i),
      ...weekend,
    ];
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        color: context.sfCard,
        border: Border.symmetric(horizontal: BorderSide(color: context.sfLine)),
      ),
      child: GestureDetector(
        // Balayer le bandeau change de semaine.
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -200) onNext();
          if (velocity > 200) onPrevious();
        },
        child: Row(
          children: [
            IconButton(
              tooltip: 'Semaine précédente',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
              color: context.sfChevron,
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: days.map((day) {
                  return _DayPill(
                    day: day,
                    count: courses
                        .where(
                          (c) =>
                              !c.isCancelled && DateUtils.isSameDay(c.day, day),
                        )
                        .length,
                    isActive:
                        selectedDay != null &&
                        DateUtils.isSameDay(day, selectedDay),
                    isToday: DateUtils.isSameDay(day, today),
                    onTap: () => onSelectDay(day),
                  );
                }).toList(),
              ),
            ),
            IconButton(
              tooltip: 'Semaine suivante',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              color: context.sfChevron,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.day,
    required this.count,
    required this.isActive,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final int count;
  final bool isActive;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const names = ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'];
    final label = names[day.weekday - 1];
    final activeText = context.sfOnAccent;
    final dotColor = isActive ? activeText : context.sfAccent;

    return InkWell(
      key: ValueKey('day-pill-${day.year}-${day.month}-${day.day}'),
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 50,
        height: 64,
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
                color: isActive ? activeText : context.sfMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.day}',
              style: TextStyle(
                color: isActive ? activeText : context.sfText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            // Un point par cours (trois au plus) : on voit les jours de cours.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < count.clamp(0, 3); i++)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (count == 0) const SizedBox(height: 5),
              ],
            ),
          ],
        ),
      ),
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
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            icon: Icon(Icons.view_day_outlined),
            label: Text('Jour'),
          ),
          ButtonSegment(
            value: true,
            icon: Icon(Icons.view_week_outlined),
            label: Text('Semaine'),
          ),
        ],
        selected: {showWholeWeek},
        onSelectionChanged: (selection) => onChanged(selection.first),
        showSelectedIcon: false,
      ),
    );
  }
}

/// Cours d'une journée, avec une vraie coupure visuelle pour les longues
/// pauses (déjeuner entre le matin et l'après-midi, par exemple).
class _DayTimeline extends StatelessWidget {
  const _DayTimeline({
    required this.day,
    required this.courses,
    required this.onEditCourse,
    required this.onDeleteCourse,
    required this.onOpenHistory,
    required this.onDuplicateCourse,
    required this.onAddHomework,
    required this.onToggleCancelled,
    this.exams = const [],
    this.onOpenExam,
    this.showHeader = true,
    this.compact = false,
    this.onOpenDay,
  });

  /// À partir de 45 min sans cours, on sépare nettement les deux blocs.
  static const longBreakMinutes = 45;

  final DateTime day;
  final List<CourseItem> courses;
  final bool showHeader;
  final bool compact;
  final VoidCallback? onOpenDay;
  final ValueChanged<CourseItem> onEditCourse;
  final ValueChanged<CourseItem> onDeleteCourse;
  final ValueChanged<CourseItem> onOpenHistory;
  final ValueChanged<CourseItem> onDuplicateCourse;
  final ValueChanged<CourseItem> onAddHomework;
  final ValueChanged<CourseItem> onToggleCancelled;
  final List<_ExamSlot> exams;
  final ValueChanged<_ExamSlot>? onOpenExam;

  @override
  Widget build(BuildContext context) {
    final sorted = [...courses]..sort(_byStart);
    final isToday = DateUtils.isSameDay(day, DateTime.now());
    final children = <Widget>[
      for (final exam in exams)
        _ExamSlotCard(
          slot: exam,
          compact: compact,
          onTap: onOpenExam == null ? null : () => onOpenExam!(exam),
        ),
    ];
    CourseItem? previous;

    for (var i = 0; i < sorted.length; i++) {
      final course = sorted[i];
      final before = previous;
      if (before != null && !before.isCancelled && !course.isCancelled) {
        final gap = course.startDateTime.difference(before.endDateTime);
        if (gap.inMinutes >= longBreakMinutes) {
          children.add(
            _BreakSeparator(
              minutes: gap.inMinutes,
              isLunch: _isLunch(before.endDateTime, course.startDateTime),
              compact: compact,
            ),
          );
        }
      }
      children.add(
        _TimelineCourseCard(
          course: course,
          paletteIndex: i,
          compact: compact,
          onEdit: () => onEditCourse(course),
          onDelete: () => onDeleteCourse(course),
          onOpenHistory: () => onOpenHistory(course),
          onDuplicate: () => onDuplicateCourse(course),
          onAddHomework: () => onAddHomework(course),
          onToggleCancelled: () => onToggleCancelled(course),
        ),
      );
      if (!course.isCancelled) previous = course;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onOpenDay,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              _weekdayLabel(day),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: context.sfText,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                  ),
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 8),
                            ProtoChip(
                              label: 'Auj.',
                              backgroundColor: context.sfSharedSoft,
                              foregroundColor: context.sfShared,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sorted.isEmpty
                          ? 'Partiels'
                          : '${sorted.first.startsAt}–${sorted.last.endsAt}',
                      style: TextStyle(color: context.sfMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }

  /// La pause recouvre l'heure du déjeuner (entre 11 h 30 et 14 h).
  static bool _isLunch(DateTime end, DateTime nextStart) {
    final lunchStart = DateTime(end.year, end.month, end.day, 11, 30);
    final lunchEnd = DateTime(end.year, end.month, end.day, 14);
    return end.isBefore(lunchEnd) && nextStart.isAfter(lunchStart);
  }
}

/// Pause entre deux cours : discrète et alignée sur les cartes (pas sous la
/// colonne des horaires), pour ne pas ressembler à une séparation de jours.
class _BreakSeparator extends StatelessWidget {
  const _BreakSeparator({
    required this.minutes,
    required this.isLunch,
    required this.compact,
  });

  /// Largeur de la colonne des horaires à gauche des cartes (vue jour).
  static const _timeColumn = 58.0;

  final int minutes;
  final bool isLunch;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = context.sfMuted;
    final line = Expanded(child: Container(height: 1, color: context.sfLine));

    return Padding(
      key: const ValueKey('long-break'),
      padding: EdgeInsets.fromLTRB(
        compact ? 24 : _timeColumn + 12,
        2,
        compact ? 24 : 12,
        compact ? 10 : 14,
      ),
      child: Row(
        children: [
          line,
          // Compressible : sur un écran étroit, l'étiquette se raccourcit.
          Flexible(
            flex: 10,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: context.sfSoftCard,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLunch ? Icons.restaurant_outlined : Icons.coffee_outlined,
                    size: 13,
                    color: color,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      '${isLunch ? 'Pause déjeuner' : 'Pause'} · ${StudyFlowFormat.duration(minutes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}

class _TimelineCourseCard extends StatelessWidget {
  const _TimelineCourseCard({
    required this.course,
    required this.paletteIndex,
    this.compact = false,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenHistory,
    required this.onDuplicate,
    required this.onAddHomework,
    required this.onToggleCancelled,
  });

  final CourseItem course;
  final int paletteIndex;
  final bool compact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenHistory;
  final VoidCallback onDuplicate;
  final VoidCallback onAddHomework;
  final VoidCallback onToggleCancelled;

  @override
  Widget build(BuildContext context) {
    final isDark = context.sfIsDark;
    final accent = course.isCancelled
        ? AppColors.rose
        : isDark
        ? _darkAccentColor
        : _accentColor;
    if (compact) {
      return _CompactCourseRow(
        course: course,
        accent: accent,
        onEdit: onEdit,
        menu: _CourseMenu(
          isCancelled: course.isCancelled,
          onToggleCancelled: onToggleCancelled,
          onEdit: onEdit,
          onAddHomework: onAddHomework,
          onDuplicate: onDuplicate,
          onOpenHistory: onOpenHistory,
          onDelete: onDelete,
        ),
      );
    }
    final cardBackground = course.isCancelled
        ? AppColors.roseSoft
        : Colors.white;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 12),
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
              padding: compact
                  ? const EdgeInsets.fromLTRB(12, 8, 6, 10)
                  : const EdgeInsets.fromLTRB(13, 13, 8, 13),
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
                              _CourseMenu(
                                isCancelled: course.isCancelled,
                                onToggleCancelled: onToggleCancelled,
                                onEdit: onEdit,
                                onAddHomework: onAddHomework,
                                onDuplicate: onDuplicate,
                                onOpenHistory: onOpenHistory,
                                onDelete: onDelete,
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

enum _CourseAction {
  toggleCancelled,
  addHomework,
  edit,
  duplicate,
  history,
  delete,
}

/// Actions d'un cours. L'annulation vient en premier : c'est le cas le plus
/// fréquent (intervenant absent), il se règle en deux touches.
class _CourseMenu extends StatelessWidget {
  const _CourseMenu({
    required this.isCancelled,
    required this.onToggleCancelled,
    required this.onEdit,
    required this.onAddHomework,
    required this.onDuplicate,
    required this.onOpenHistory,
    required this.onDelete,
  });

  final bool isCancelled;
  final VoidCallback onToggleCancelled;
  final VoidCallback onEdit;
  final VoidCallback onAddHomework;
  final VoidCallback onDuplicate;
  final VoidCallback onOpenHistory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CourseAction>(
      tooltip: 'Actions cours',
      icon: const Icon(Icons.more_horiz),
      color: context.sfCard,
      onSelected: (action) {
        switch (action) {
          case _CourseAction.toggleCancelled:
            onToggleCancelled();
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
      itemBuilder: (context) => [
        PopupMenuItem(
          key: const ValueKey('course-toggle-cancelled'),
          value: _CourseAction.toggleCancelled,
          child: ListTile(
            leading: Icon(
              isCancelled ? Icons.event_available_outlined : Icons.event_busy,
              color: isCancelled ? null : AppColors.rose,
            ),
            title: Text(isCancelled ? 'Rétablir le cours' : 'Annuler le cours'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _CourseAction.addHomework,
          child: ListTile(
            leading: Icon(Icons.assignment_add),
            title: Text('Ajouter un devoir'),
          ),
        ),
        const PopupMenuItem(
          value: _CourseAction.edit,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Modifier'),
          ),
        ),
        const PopupMenuItem(
          value: _CourseAction.duplicate,
          child: ListTile(
            leading: Icon(Icons.copy_all_outlined),
            title: Text('Dupliquer'),
          ),
        ),
        const PopupMenuItem(
          value: _CourseAction.history,
          child: ListTile(
            leading: Icon(Icons.history_outlined),
            title: Text('Historique'),
          ),
        ),
        const PopupMenuItem(
          value: _CourseAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Supprimer'),
          ),
        ),
      ],
    );
  }
}

class _ExamSlot {
  const _ExamSlot({required this.session, required this.subject});

  final ExamSession session;
  final ExamSubjectSummary subject;
}

/// Épreuve de partiel dans le planning, en ambre comme les évaluations.
class _ExamSlotCard extends StatelessWidget {
  const _ExamSlotCard({
    required this.slot,
    required this.compact,
    required this.onTap,
  });

  final _ExamSlot slot;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subject = slot.subject;
    final accent = context.sfEvaluation;
    final details = [slot.session.title, ?subject.details].join(' · ');

    final card = ProtoCard(
      key: ValueKey('schedule-exam-${subject.id}'),
      onTap: onTap,
      margin: EdgeInsets.only(bottom: compact ? 8 : 12),
      padding: EdgeInsets.fromLTRB(12, compact ? 10 : 13, 8, compact ? 10 : 13),
      borderColor: accent,
      backgroundColor: context.sfEvaluationSoft,
      child: Row(
        children: [
          Icon(Icons.grading_outlined, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.startsAt == null
                      ? 'PARTIEL'
                      : 'PARTIEL · ${subject.startsAt}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  subject.name,
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: compact ? 15 : 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!compact)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ProtoMutedText(details, maxLines: 2),
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: accent),
        ],
      ),
    );

    if (compact) return card;
    // Même alignement que les cours : colonne d'horaire à gauche.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Text(
              subject.startsAt ?? '',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.sfText,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: card),
      ],
    );
  }
}

/// Confirme l'annulation et propose d'annuler les autres cours du jour
/// (« Oui » par défaut). Renvoie `true` pour tout annuler, `false` pour ce
/// seul cours, `null` si l'élève renonce.
class _CancelCourseDialog extends StatefulWidget {
  const _CancelCourseDialog({required this.course, required this.others});

  final CourseItem course;
  final List<CourseItem> others;

  @override
  State<_CancelCourseDialog> createState() => _CancelCourseDialogState();
}

class _CancelCourseDialogState extends State<_CancelCourseDialog> {
  bool _alsoOthers = true;

  @override
  Widget build(BuildContext context) {
    final others = widget.others;

    return AlertDialog(
      title: Text('Annuler ${widget.course.subjectName} ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Le cours de ${widget.course.startsAt} sera marqué annulé pour '
            'toute la classe.',
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            key: const ValueKey('cancel-whole-day-switch'),
            contentPadding: EdgeInsets.zero,
            value: _alsoOthers,
            onChanged: (value) => setState(() => _alsoOthers = value),
            title: Text(
              others.length == 1
                  ? 'Annuler aussi l’autre cours de la journée'
                  : 'Annuler aussi les ${others.length} autres cours de la journée',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              others
                  .map((other) => '${other.startsAt} ${other.subjectName}')
                  .join(' · '),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
        FilledButton(
          key: const ValueKey('confirm-cancel-course'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, _alsoOthers),
          child: Text(_alsoOthers ? 'Tout annuler' : 'Annuler ce cours'),
        ),
      ],
    );
  }
}

/// Une ligne par cours dans la vue semaine : horaire, matière, salle.
class _CompactCourseRow extends StatelessWidget {
  const _CompactCourseRow({
    required this.course,
    required this.accent,
    required this.onEdit,
    required this.menu,
  });

  final CourseItem course;
  final Color accent;
  final VoidCallback onEdit;
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    final details = [
      'Salle ${course.room}',
      ?course.teacherName,
      if (course.isCancelled) 'Annulé',
    ].join(' · ');

    return ProtoCard(
      onTap: onEdit,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
      backgroundColor: course.isCancelled ? AppColors.roseSoft : Colors.white,
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.startsAt,
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  course.endsAt,
                  style: TextStyle(color: context.sfMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.subjectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    decoration: course.isCancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.sfMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          menu,
        ],
      ),
    );
  }
}

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
