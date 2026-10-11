import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/classes/domain/class_resource_models.dart';
import 'package:studyflow_app/features/classes/presentation/class_resources_page.dart';
import 'package:studyflow_app/features/schedule/domain/course_models.dart';

/// Formulaire plein écran pour ajouter ou modifier un cours.
///
/// La matière et l'intervenant se choisissent en un geste (pas de liste
/// déroulante qui garde le clavier ouvert). En création, on peut ajouter
/// plusieurs créneaux le même jour et répéter le tout chaque semaine.
class CourseFormPage extends StatefulWidget {
  const CourseFormPage({
    required this.initialDay,
    this.course,
    this.template,
    super.key,
  });

  /// Cours modifié. Nul en création.
  final CourseItem? course;

  /// Valeurs de départ en création (par exemple pour dupliquer un cours).
  final CourseFormData? template;

  final DateTime initialDay;

  static Future<bool?> open(
    BuildContext context, {
    required DateTime initialDay,
    CourseItem? course,
    CourseFormData? template,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => CourseFormPage(
          initialDay: initialDay,
          course: course,
          template: template,
        ),
      ),
    );
  }

  @override
  State<CourseFormPage> createState() => _CourseFormPageState();
}

class _Slot {
  _Slot(this.start, this.end);

  TimeOfDay start;
  TimeOfDay end;

  int get durationMinutes =>
      StudyFlowFormat.minutes(end) - StudyFlowFormat.minutes(start);
}

class _CourseFormPageState extends State<CourseFormPage> {
  static const _maxCourses = 120;

  late final TextEditingController _roomController;
  late DateTime _day;
  late final List<_Slot> _slots;
  String? _subjectId;
  String? _teacherId;
  bool _showAllTeachers = false;
  bool _isCancelled = false;
  bool _repeatWeekly = false;
  late DateTime _repeatUntil;
  bool _isSaving = false;
  String? _error;
  Future<ClassResources>? _resourcesFuture;

  /// Cours du mois du jour choisi : pour proposer l'heure qui suit le dernier
  /// cours de la journée et les salles utilisées ce mois-ci.
  List<CourseItem> _monthCourses = const [];
  DateTime? _loadedMonth;

  /// L'élève a choisi lui-même un horaire : on ne le change plus.
  bool _timesTouched = false;

  bool get _isEditing => widget.course != null;

  @override
  void initState() {
    super.initState();
    final source = widget.course?.toFormData() ?? widget.template;
    _day = DateUtils.dateOnly(source?.day ?? widget.initialDay);
    _subjectId = source?.subjectId;
    _teacherId = source?.teacherId;
    _roomController = TextEditingController(text: source?.room ?? '');
    _isCancelled = widget.course?.isCancelled ?? false;
    _slots = [
      _Slot(
        StudyFlowFormat.parseTime(source?.startsAt) ??
            const TimeOfDay(hour: 8, minute: 0),
        StudyFlowFormat.parseTime(source?.endsAt) ??
            const TimeOfDay(hour: 9, minute: 30),
      ),
    ];
    _repeatUntil = StudyFlowDates.addDays(_day, 7 * 8);
    _timesTouched = source != null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resourcesFuture ??= ClassResources.load(context);
    if (_loadedMonth == null) _loadMonth();
  }

  Future<void> _loadMonth() async {
    final month = DateTime(_day.year, _day.month);
    if (_loadedMonth == month) {
      _suggestTimes();
      return;
    }
    _loadedMonth = month;

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final courses = await appScope.courseRepository.listCourses(
        from: month,
        to: DateTime(month.year, month.month + 1, 0),
        accessToken: accessToken,
      );
      if (!mounted) return;
      setState(() {
        _monthCourses = courses;
        _suggestTimes();
        _suggestRoom();
      });
    } on Exception {
      // Sans ces suggestions, le formulaire reste utilisable.
    }
  }

  /// Nouveau cours : il commence après le dernier cours du jour (15 min de
  /// pause, ou 14 h si ce dernier finit à l'heure du déjeuner).
  void _suggestTimes() {
    if (_timesTouched || _isEditing) return;
    final dayCourses =
        _monthCourses
            .where((x) => !x.isCancelled && DateUtils.isSameDay(x.day, _day))
            .toList()
          ..sort((a, b) => a.endsAt.compareTo(b.endsAt));
    final slot = nextCourseSlot(dayCourses);
    _slots
      ..clear()
      ..add(_Slot(slot.$1, slot.$2));
  }

  /// La matière a souvent la même salle : on la propose si le champ est vide.
  void _suggestRoom() {
    if (_roomController.text.trim().isNotEmpty || _subjectId == null) return;
    final rooms = roomSuggestions(_monthCourses, subjectId: _subjectId);
    final usedForSubject = _monthCourses.any(
      (x) => x.subjectId == _subjectId && x.room.trim().isNotEmpty,
    );
    if (usedForSubject && rooms.isNotEmpty) _roomController.text = rooms.first;
  }

  @override
  Widget build(BuildContext context) {
    final isDelegate =
        AppScope.of(context).sessionController.session?.user.isDelegate == true;

    return GestureDetector(
      // Toucher en dehors d'un champ ferme le clavier.
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            onPressed: _isSaving ? null : () => Navigator.pop(context),
          ),
          title: Text(_isEditing ? 'Modifier le cours' : 'Nouveau cours'),
        ),
        body: FutureBuilder<ClassResources>(
          future: _resourcesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ProtoPageLoader(label: 'Matières de la classe');
            }
            if (snapshot.hasError) {
              return ProtoStateCard(
                icon: Icons.cloud_off_outlined,
                title: 'Matières indisponibles',
                message: 'Impossible de charger les matières de la classe.',
                actionLabel: 'Réessayer',
                onAction: _reloadResources,
              );
            }

            final resources = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                const ProtoVisibilityBanner(shared: true),
                const SizedBox(height: 20),
                _buildSubjectSection(resources, isDelegate),
                const SizedBox(height: 20),
                _buildTeacherSection(resources, isDelegate),
                const SizedBox(height: 20),
                const ProtoFormLabel('Date'),
                ProtoPickerField(
                  keyValue: 'course-day-field',
                  icon: Icons.calendar_today_outlined,
                  label: 'Jour du cours',
                  value: StudyFlowFormat.longDay(_day),
                  onTap: _pickDay,
                ),
                const SizedBox(height: 20),
                _buildSlotsSection(),
                const SizedBox(height: 20),
                _buildRoomSection(),
                if (!_isEditing) ...[
                  const SizedBox(height: 20),
                  _buildRepeatSection(),
                ] else ...[
                  const SizedBox(height: 20),
                  ProtoCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isCancelled,
                      onChanged: (value) =>
                          setState(() => _isCancelled = value),
                      title: const Text('Cours annulé'),
                      subtitle: const Text(
                        'Il reste visible, barré, pour toute la classe.',
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            key: const ValueKey('course-save-button'),
            onPressed: _isSaving ? null : _save,
            child: Text(_isSaving ? 'Enregistrement…' : _saveLabel),
          ),
        ),
      ),
    );
  }

  String get _saveLabel {
    if (_isEditing) return 'Enregistrer';
    final count = _expandedCount;
    return count <= 1 ? 'Ajouter le cours' : 'Ajouter $count cours';
  }

  int get _expandedCount => _slots.length * _weeks.length;

  List<DateTime> get _weeks {
    if (_isEditing || !_repeatWeekly) return [_day];
    final days = <DateTime>[];
    for (
      var day = _day;
      !day.isAfter(_repeatUntil);
      day = StudyFlowDates.addDays(day, 7)
    ) {
      days.add(day);
    }
    return days;
  }

  Widget _buildSubjectSection(ClassResources resources, bool isDelegate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProtoFormLabel('Matière'),
        if (resources.subjects.isEmpty)
          ProtoStateCard(
            icon: Icons.menu_book_outlined,
            title: 'Aucune matière dans la classe',
            message: isDelegate
                ? 'Ajoute la première matière pour pouvoir créer le cours.'
                : 'Demande à ton délégué d’ajouter les matières de la classe.',
            actionLabel: isDelegate ? 'Ajouter une matière' : null,
            actionIcon: Icons.add,
            onAction: isDelegate ? () => _createSubject(resources) : null,
            compact: true,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final subject in resources.subjects)
                ChoiceChip(
                  key: ValueKey('subject-chip-${subject.id}'),
                  label: Text(subject.name),
                  selected: _subjectId == subject.id,
                  onSelected: (_) => _selectSubject(resources, subject.id),
                ),
              if (isDelegate)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Nouvelle'),
                  onPressed: () => _createSubject(resources),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildTeacherSection(ClassResources resources, bool isDelegate) {
    final subjectId = _subjectId;
    final linked = subjectId == null
        ? <ClassTeacher>[]
        : resources.teachersOf(subjectId);
    final others = resources.teachers
        .where((teacher) => !linked.any((x) => x.id == teacher.id))
        .toList();
    final selectedIsOther = others.any((x) => x.id == _teacherId);
    final visibleOthers = _showAllTeachers || selectedIsOther
        ? others
        : <ClassTeacher>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProtoFormLabel(
          'Intervenant',
          trailing: Text(
            'optionnel',
            style: TextStyle(color: context.sfMuted, fontSize: 12),
          ),
        ),
        if (subjectId == null)
          const ProtoMutedText(
            'Choisis d’abord la matière : ses intervenants seront proposés ici.',
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Aucun'),
                selected: _teacherId == null,
                onSelected: (_) => _selectTeacher(null),
              ),
              for (final teacher in [...linked, ...visibleOthers])
                ChoiceChip(
                  key: ValueKey('teacher-chip-${teacher.id}'),
                  label: Text(teacher.displayName),
                  selected: _teacherId == teacher.id,
                  onSelected: (_) => _selectTeacher(teacher.id),
                ),
              if (others.isNotEmpty && visibleOthers.isEmpty)
                ActionChip(
                  avatar: const Icon(Icons.unfold_more, size: 18),
                  label: Text('Autres (${others.length})'),
                  onPressed: () => setState(() => _showAllTeachers = true),
                ),
              if (isDelegate)
                ActionChip(
                  avatar: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Nouvel intervenant'),
                  onPressed: () => _createTeacher(resources),
                ),
            ],
          ),
          if (linked.isEmpty) ...[
            const SizedBox(height: 8),
            const ProtoMutedText(
              'Aucun intervenant rattaché à cette matière. Celui que tu choisis le sera automatiquement.',
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSlotsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProtoFormLabel(_slots.length > 1 ? 'Créneaux' : 'Horaire'),
        for (var index = 0; index < _slots.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SlotRow(
              index: index,
              slot: _slots[index],
              showIndex: _slots.length > 1,
              onPickStart: () => _pickSlotTime(index, isStart: true),
              onPickEnd: () => _pickSlotTime(index, isStart: false),
              onRemove: _slots.length > 1
                  ? () => setState(() => _slots.removeAt(index))
                  : null,
            ),
          ),
        if (!_isEditing)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('add-slot-button'),
              onPressed: _addSlot,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter un créneau ce jour-là'),
            ),
          ),
      ],
    );
  }

  Widget _buildRoomSection() {
    final suggestions = roomSuggestions(
      _monthCourses,
      subjectId: _subjectId,
    ).take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProtoFormLabel('Salle'),
        TextField(
          key: const ValueKey('course-room-field'),
          controller: _roomController,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: const InputDecoration(
            hintText: 'B204',
            prefixIcon: Icon(Icons.meeting_room_outlined),
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Salles utilisées en ${_monthName(_day)}',
            style: TextStyle(color: context.sfMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map(
                  (room) => ActionChip(
                    label: Text(room),
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() => _roomController.text = room);
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildRepeatSection() {
    final weeks = _weeks.length;

    return ProtoCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            key: const ValueKey('repeat-weekly-switch'),
            contentPadding: EdgeInsets.zero,
            value: _repeatWeekly,
            onChanged: (value) {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => _repeatWeekly = value);
            },
            title: const Text('Répéter chaque semaine'),
            subtitle: Text(
              'Même jour (${StudyFlowFormat.longDay(_day).split(' ').first.toLowerCase()}), mêmes horaires.',
            ),
          ),
          if (_repeatWeekly) ...[
            ProtoPickerField(
              icon: Icons.event_repeat_outlined,
              label: 'Jusqu’au',
              value: StudyFlowFormat.longDay(_repeatUntil),
              onTap: _pickRepeatUntil,
            ),
            const SizedBox(height: 8),
            ProtoMutedText(
              '$weeks semaine${weeks > 1 ? 's' : ''} × ${_slots.length} créneau${_slots.length > 1 ? 'x' : ''} = $_expandedCount cours.',
            ),
          ],
        ],
      ),
    );
  }

  void _selectSubject(ClassResources resources, String subjectId) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      final changed = _subjectId != subjectId;
      _subjectId = subjectId;
      _showAllTeachers = false;
      if (!changed) return;

      // Un seul intervenant pour la matière : on le choisit d'office.
      final linked = resources.teachersOf(subjectId);
      final keepsTeacher = linked.any((x) => x.id == _teacherId);
      if (!keepsTeacher) {
        _teacherId = linked.length == 1 ? linked.first.id : null;
      }
      _suggestRoom();
    });
  }

  void _selectTeacher(String? teacherId) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _teacherId = teacherId);
  }

  Future<void> _createSubject(ClassResources resources) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final created = await showSubjectFormSheet(context, resources: resources);
    if (created is! ClassSubject || !mounted) return;
    final reloaded = await _reloadResources();
    if (!mounted) return;
    // L'intervenant rattaché pendant la création de la matière est sélectionné
    // d'office (le premier s'il y en a plusieurs).
    _selectSubject(reloaded, created.id);
    final linked = reloaded.teachersOf(created.id);
    if (_teacherId == null && linked.isNotEmpty) {
      setState(() => _teacherId = linked.first.id);
    }
  }

  Future<void> _createTeacher(ClassResources resources) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final created = await showTeacherFormSheet(
      context,
      resources: resources,
      initialSubjectIds: [?_subjectId],
    );
    if (created is! ClassTeacher || !mounted) return;
    await _reloadResources();
    if (mounted) setState(() => _teacherId = created.id);
  }

  Future<ClassResources> _reloadResources() async {
    final future = ClassResources.load(context);
    setState(() {
      _resourcesFuture = future;
    });
    return future;
  }

  Future<void> _pickDay() async {
    final picked = await StudyFlowPickers.pickDate(
      context,
      initialDate: _day,
      helpText: 'Jour du cours',
    );
    if (picked == null) return;
    setState(() {
      _day = DateUtils.dateOnly(picked);
      if (_repeatUntil.isBefore(_day)) {
        _repeatUntil = StudyFlowDates.addDays(_day, 7 * 8);
      }
    });
    await _loadMonth();
    if (mounted) setState(() {});
  }

  Future<void> _pickRepeatUntil() async {
    final picked = await StudyFlowPickers.pickDate(
      context,
      initialDate: _repeatUntil,
      firstDate: _day,
      lastDate: StudyFlowDates.addDays(_day, 365),
      helpText: 'Dernière semaine',
    );
    if (picked != null) {
      setState(() => _repeatUntil = DateUtils.dateOnly(picked));
    }
  }

  Future<void> _pickSlotTime(int index, {required bool isStart}) async {
    final slot = _slots[index];
    final picked = await StudyFlowPickers.pickTime(
      context,
      initialTime: isStart ? slot.start : slot.end,
      title: isStart ? 'Début du cours' : 'Fin du cours',
    );
    if (picked == null) return;

    setState(() {
      _timesTouched = true;
      if (isStart) {
        // Décaler le début garde la même durée.
        final duration = slot.durationMinutes > 0 ? slot.durationMinutes : 60;
        slot.start = picked;
        slot.end = StudyFlowFormat.fromMinutes(
          StudyFlowFormat.minutes(picked) + duration,
        );
      } else {
        slot.end = picked;
      }
    });
  }

  void _addSlot() {
    FocusManager.instance.primaryFocus?.unfocus();
    _timesTouched = true;
    final last = _slots.last;
    final duration = last.durationMinutes > 0 ? last.durationMinutes : 90;
    final start = StudyFlowFormat.minutes(last.end) + 15;
    setState(() {
      _slots.add(
        _Slot(
          StudyFlowFormat.fromMinutes(start),
          StudyFlowFormat.fromMinutes(start + duration),
        ),
      );
    });
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final appScope = AppScope.of(context);
    final resources = await _resourcesFuture;
    final subject = resources?.subjectById(_subjectId);
    final room = _roomController.text.trim();

    String? problem;
    if (subject == null) {
      problem = 'Choisis la matière du cours.';
    } else if (_slots.any((slot) => slot.durationMinutes <= 0)) {
      problem = 'L’heure de fin doit être après l’heure de début.';
    } else if (room.isEmpty) {
      problem = 'Indique la salle (ou « Distanciel »).';
    } else if (_expandedCount > _maxCourses) {
      problem =
          'Ça fait $_expandedCount cours : réduis la période (maximum $_maxCourses).';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final teacher = resources!.teacherById(_teacherId);
    final courses = [
      for (final day in _weeks)
        for (final slot in _slots)
          CourseFormData(
            subjectId: subject!.id,
            subjectName: subject.name,
            teacherId: teacher?.id,
            teacherName: teacher?.displayName,
            day: day,
            startsAt: StudyFlowFormat.time(slot.start),
            endsAt: StudyFlowFormat.time(slot.end),
            room: room,
            isCancelled: _isCancelled,
            version: widget.course?.version,
          ),
    ];

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final repository = appScope.courseRepository;
      final course = widget.course;
      if (course != null) {
        await repository.updateCourse(
          courseId: course.id,
          data: courses.single,
          accessToken: accessToken,
        );
      } else if (courses.length == 1) {
        await repository.createCourse(
          data: courses.single,
          accessToken: accessToken,
        );
      } else {
        await repository.createCourses(
          courses: courses,
          accessToken: accessToken,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (!mounted) return;
      final text = error.toString();
      setState(
        () =>
            _error = text.startsWith('Bad state: ') ? text.substring(11) : text,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }
}

String _monthName(DateTime day) {
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return months[day.month - 1];
}

/// Créneau proposé pour un nouveau cours, d'après les cours déjà prévus ce
/// jour-là (triés ou non) : après le dernier, avec la même durée.
(TimeOfDay, TimeOfDay) nextCourseSlot(List<CourseItem> dayCourses) {
  if (dayCourses.isEmpty) {
    return (
      const TimeOfDay(hour: 8, minute: 0),
      const TimeOfDay(hour: 9, minute: 30),
    );
  }

  final last = dayCourses.reduce(
    (a, b) => a.endsAt.compareTo(b.endsAt) >= 0 ? a : b,
  );
  final lastStart = StudyFlowFormat.minutes(
    StudyFlowFormat.parseTime(last.startsAt)!,
  );
  final lastEnd = StudyFlowFormat.minutes(
    StudyFlowFormat.parseTime(last.endsAt)!,
  );
  final duration = lastEnd > lastStart ? lastEnd - lastStart : 90;

  // Fin de matinée vers midi : l'après-midi reprend à 14 h.
  var start = lastEnd >= 12 * 60 && lastEnd < 14 * 60 ? 14 * 60 : lastEnd + 15;
  start = ((start + 4) ~/ 5) * 5;
  return (
    StudyFlowFormat.fromMinutes(start),
    StudyFlowFormat.fromMinutes(start + duration),
  );
}

/// Salles du mois, les plus utilisées d'abord ; celles de la matière en tête.
List<String> roomSuggestions(List<CourseItem> courses, {String? subjectId}) {
  final counts = <String, int>{};
  final forSubject = <String, int>{};
  for (final course in courses) {
    final room = course.room.trim();
    if (room.isEmpty) continue;
    counts[room] = (counts[room] ?? 0) + 1;
    if (course.subjectId == subjectId) {
      forSubject[room] = (forSubject[room] ?? 0) + 1;
    }
  }

  final rooms = counts.keys.toList()
    ..sort((a, b) {
      final bySubject = (forSubject[b] ?? 0).compareTo(forSubject[a] ?? 0);
      if (bySubject != 0) return bySubject;
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return rooms;
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.index,
    required this.slot,
    required this.showIndex,
    required this.onPickStart,
    required this.onPickEnd,
    this.onRemove,
  });

  final int index;
  final _Slot slot;
  final bool showIndex;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final duration = slot.durationMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ProtoPickerField(
                keyValue: 'slot-$index-start',
                icon: Icons.schedule_outlined,
                label: showIndex ? 'Début ${index + 1}' : 'Début',
                value: StudyFlowFormat.time(slot.start),
                onTap: onPickStart,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ProtoPickerField(
                keyValue: 'slot-$index-end',
                icon: Icons.schedule,
                label: 'Fin',
                value: StudyFlowFormat.time(slot.end),
                onTap: onPickEnd,
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: 'Retirer ce créneau',
                onPressed: onRemove,
                icon: const Icon(Icons.remove_circle_outline),
                color: context.sfMuted,
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Text(
            duration > 0
                ? 'Durée : ${StudyFlowFormat.duration(duration)}'
                : 'La fin doit être après le début',
            style: TextStyle(
              color: duration > 0 ? context.sfMuted : AppColors.danger,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
