import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/agenda/domain/agenda_models.dart';
import 'package:studyflow_app/features/classes/domain/class_resource_models.dart';
import 'package:studyflow_app/features/classes/presentation/class_resources_page.dart';
import 'package:studyflow_app/features/schedule/domain/course_models.dart';
import 'package:studyflow_app/features/schedule/presentation/course_form_page.dart';

/// Devoir de classe : toujours rattaché au cours pour lequel il est à faire.
///
/// On choisit la matière, puis le cours (le prochain est présélectionné) ;
/// l'échéance est par défaut le début de ce cours.
class HomeworkFormPage extends StatefulWidget {
  const HomeworkFormPage({this.homework, this.initialCourse, super.key});

  final HomeworkItem? homework;

  /// Cours d'où l'on ajoute le devoir (depuis le planning).
  final CourseItem? initialCourse;

  static Future<bool?> open(
    BuildContext context, {
    HomeworkItem? homework,
    CourseItem? initialCourse,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            HomeworkFormPage(homework: homework, initialCourse: initialCourse),
      ),
    );
  }

  @override
  State<HomeworkFormPage> createState() => _HomeworkFormPageState();
}

class _HomeworkChoices {
  const _HomeworkChoices({required this.resources, required this.courses});

  final ClassResources resources;
  final List<CourseItem> courses;

  List<CourseItem> coursesOf(String subjectId) => courses
      .where((course) => course.subjectId == subjectId && !course.isCancelled)
      .toList(growable: false);

  CourseItem? courseById(String? id) {
    for (final course in courses) {
      if (course.id == id) return course;
    }
    return null;
  }
}

class _HomeworkFormPageState extends State<HomeworkFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  Future<_HomeworkChoices>? _choicesFuture;
  String? _subjectId;
  String? _courseId;
  bool _dueAtCourseStart = true;
  late DateTime _customDeadline;
  bool _showPastCourses = false;
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.homework != null;

  @override
  void initState() {
    super.initState();
    final homework = widget.homework;
    _titleController = TextEditingController(text: homework?.title ?? '');
    _descriptionController = TextEditingController(
      text: homework?.description ?? '',
    );
    _courseId = homework?.courseId ?? widget.initialCourse?.id;
    _subjectId = widget.initialCourse?.subjectId;
    _customDeadline =
        homework?.deadline ??
        widget.initialCourse?.startDateTime ??
        DateTime.now().add(const Duration(days: 1));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _choicesFuture ??= _loadChoices();
  }

  Future<_HomeworkChoices> _loadChoices() async {
    final appScope = AppScope.of(context);
    final resources = ClassResources.load(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    final today = DateUtils.dateOnly(DateTime.now());
    final courses = await appScope.courseRepository.listCourses(
      from: StudyFlowDates.addDays(today, -14),
      to: StudyFlowDates.addDays(today, 7 * 8),
      accessToken: accessToken,
    );
    final sorted = [...courses]
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    final choices = _HomeworkChoices(
      resources: await resources,
      courses: sorted,
    );

    // En modification, on retrouve la matière à partir du cours lié et on
    // regarde si l'échéance correspond encore au début du cours.
    final linked = choices.courseById(_courseId);
    if (linked != null) {
      _subjectId ??= linked.subjectId;
      final homework = widget.homework;
      if (homework != null) {
        _dueAtCourseStart = homework.deadline.isAtSameMomentAs(
          linked.startDateTime,
        );
      }
    } else if (widget.homework != null) {
      // Cours lié hors de la période chargée : on garde l'échéance enregistrée.
      _dueAtCourseStart = false;
    }
    return choices;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            onPressed: _isSaving ? null : () => Navigator.pop(context),
          ),
          title: Text(_isEditing ? 'Modifier le devoir' : 'Nouveau devoir'),
        ),
        body: FutureBuilder<_HomeworkChoices>(
          future: _choicesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ProtoPageLoader(label: 'Cours de la classe');
            }
            if (snapshot.hasError) {
              return ProtoStateCard(
                icon: Icons.cloud_off_outlined,
                title: 'Cours indisponibles',
                message: 'Impossible de charger le planning de la classe.',
                actionLabel: 'Réessayer',
                onAction: () => setState(() {
                  _choicesFuture = _loadChoices();
                }),
              );
            }

            final choices = snapshot.requireData;
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  const ProtoVisibilityBanner(shared: true),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const ValueKey('homework-title-field'),
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'À faire',
                      hintText: 'Exercices 3 à 5 page 42',
                      prefixIcon: Icon(Icons.assignment_outlined),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Décris le devoir en quelques mots.'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _buildSubjectSection(choices),
                  const SizedBox(height: 20),
                  _buildCourseSection(choices),
                  const SizedBox(height: 20),
                  _buildDeadlineSection(choices),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Détails (optionnel)',
                      hintText: 'Consignes, format de rendu…',
                      alignLabelWithHint: true,
                    ),
                  ),
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
              ),
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            key: const ValueKey('homework-save-button'),
            onPressed: _isSaving ? null : _save,
            child: Text(
              _isSaving
                  ? 'Enregistrement…'
                  : _isEditing
                  ? 'Enregistrer'
                  : 'Ajouter le devoir',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectSection(_HomeworkChoices choices) {
    final subjects = choices.resources.subjects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProtoFormLabel('Matière'),
        if (subjects.isEmpty)
          const ProtoMutedText(
            'Aucune matière dans la classe pour l’instant. Le délégué peut les ajouter depuis le profil.',
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final subject in subjects)
                ChoiceChip(
                  key: ValueKey('homework-subject-${subject.id}'),
                  label: Text(subject.name),
                  selected: _subjectId == subject.id,
                  onSelected: (_) => _selectSubject(choices, subject),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildCourseSection(_HomeworkChoices choices) {
    final subjectId = _subjectId;
    if (subjectId == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProtoFormLabel('Pour quel cours ?'),
          ProtoMutedText(
            'Choisis la matière : ses prochains cours s’afficheront ici.',
          ),
        ],
      );
    }

    final now = DateTime.now();
    final all = choices.coursesOf(subjectId);
    final upcoming = all.where((x) => x.endDateTime.isAfter(now)).toList();
    final past = all.where((x) => !x.endDateTime.isAfter(now)).toList();
    final selectedIsPast = past.any((x) => x.id == _courseId);
    final visible = [
      if (_showPastCourses || selectedIsPast)
        ...past.reversed.take(4).toList().reversed,
      ...upcoming.take(6),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProtoFormLabel('Pour quel cours ?'),
        if (visible.isEmpty)
          ProtoStateCard(
            icon: Icons.event_busy_outlined,
            title: 'Aucun cours de cette matière au planning',
            message:
                'Ajoute d’abord le cours au planning de la classe, puis rattache-lui le devoir.',
            actionLabel: 'Ajouter le cours',
            actionIcon: Icons.add,
            onAction: () => _createCourse(subjectId, choices),
            compact: true,
          )
        else
          ...visible.map(
            (course) => _CourseChoiceTile(
              course: course,
              selected: course.id == _courseId,
              isNext: upcoming.isNotEmpty && course.id == upcoming.first.id,
              onTap: () => _selectCourse(course),
            ),
          ),
        if (past.isNotEmpty && !_showPastCourses && !selectedIsPast)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showPastCourses = true),
              child: const Text('Voir les cours passés'),
            ),
          ),
      ],
    );
  }

  Widget _buildDeadlineSection(_HomeworkChoices choices) {
    final course = choices.courseById(_courseId);
    final deadline = _deadlineFor(course);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProtoFormLabel('Échéance'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Au début du cours'),
              selected: _dueAtCourseStart,
              onSelected: course == null
                  ? null
                  : (_) => setState(() => _dueAtCourseStart = true),
            ),
            ChoiceChip(
              key: const ValueKey('homework-custom-deadline'),
              label: const Text('Autre date'),
              selected: !_dueAtCourseStart,
              onSelected: (_) => setState(() {
                _dueAtCourseStart = false;
                _customDeadline = deadline ?? _customDeadline;
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_dueAtCourseStart)
          ProtoMutedText(
            deadline == null
                ? 'Choisis le cours pour fixer l’échéance.'
                : 'À rendre le ${StudyFlowFormat.longDay(deadline).toLowerCase()} à ${StudyFlowFormat.timeOf(deadline)}.',
          )
        else
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ProtoPickerField(
                  icon: Icons.calendar_today_outlined,
                  label: 'Jour',
                  value: StudyFlowFormat.shortDay(_customDeadline),
                  onTap: _pickDeadlineDay,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ProtoPickerField(
                  icon: Icons.schedule_outlined,
                  label: 'Heure',
                  value: StudyFlowFormat.timeOf(_customDeadline),
                  onTap: _pickDeadlineTime,
                ),
              ),
            ],
          ),
      ],
    );
  }

  DateTime? _deadlineFor(CourseItem? course) {
    if (!_dueAtCourseStart) return _customDeadline;
    return course?.startDateTime;
  }

  void _selectSubject(_HomeworkChoices choices, ClassSubject subject) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_subjectId == subject.id) return;

    // Le prochain cours de la matière est le choix le plus probable.
    final now = DateTime.now();
    final next = choices
        .coursesOf(subject.id)
        .where((x) => x.endDateTime.isAfter(now))
        .firstOrNull;
    setState(() {
      _subjectId = subject.id;
      _courseId = next?.id;
      _showPastCourses = false;
      _error = null;
    });
  }

  void _selectCourse(CourseItem course) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _courseId = course.id;
      _error = null;
    });
  }

  Future<void> _createCourse(String subjectId, _HomeworkChoices choices) async {
    final subject = choices.resources.subjectById(subjectId);
    final created = await CourseFormPage.open(
      context,
      initialDay: DateTime.now(),
      template: subject == null
          ? null
          : CourseFormData(
              subjectId: subject.id,
              subjectName: subject.name,
              day: DateTime.now(),
              startsAt: '08:00',
              endsAt: '09:30',
              room: '',
            ),
    );
    if (created != true || !mounted) return;

    final future = _loadChoices();
    setState(() {
      _choicesFuture = future;
    });
    final reloaded = await future;
    if (!mounted) return;
    final next = reloaded
        .coursesOf(subjectId)
        .where((x) => x.endDateTime.isAfter(DateTime.now()))
        .firstOrNull;
    setState(() => _courseId = next?.id);
  }

  Future<void> _pickDeadlineDay() async {
    final picked = await StudyFlowPickers.pickDate(
      context,
      initialDate: _customDeadline,
      helpText: 'Jour de rendu',
    );
    if (picked == null) return;
    setState(() {
      _customDeadline = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _customDeadline.hour,
        _customDeadline.minute,
      );
    });
  }

  Future<void> _pickDeadlineTime() async {
    final picked = await StudyFlowPickers.pickTime(
      context,
      initialTime: TimeOfDay.fromDateTime(_customDeadline),
      title: 'Heure de rendu',
    );
    if (picked == null) return;
    setState(() {
      _customDeadline = DateTime(
        _customDeadline.year,
        _customDeadline.month,
        _customDeadline.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    final appScope = AppScope.of(context);
    final choices = await _choicesFuture;
    final course = choices?.courseById(_courseId);
    final deadline = _deadlineFor(course);
    if (course == null && _courseId == null) {
      setState(
        () => _error = 'Choisis le cours pour lequel ce devoir est à faire.',
      );
      return;
    }
    if (deadline == null) {
      setState(() => _error = 'Choisis l’échéance du devoir.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    final request = CreateHomeworkRequest(
      title: _titleController.text.trim(),
      description: _descriptionController.text,
      deadline: deadline,
      courseId: _courseId,
      subjectName: course?.subjectName ?? widget.homework?.subjectName,
      courseDay: course?.day ?? widget.homework?.courseDay,
    );

    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final homework = widget.homework;
      if (homework == null) {
        await appScope.agendaRepository.createHomework(
          request: request,
          accessToken: accessToken,
        );
      } else {
        await appScope.agendaRepository.updateHomework(
          homeworkId: homework.id,
          request: request,
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
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class _CourseChoiceTile extends StatelessWidget {
  const _CourseChoiceTile({
    required this.course,
    required this.selected,
    required this.isNext,
    required this.onTap,
  });

  final CourseItem course;
  final bool selected;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.sfShared;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? context.sfSharedSoft : context.sfCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('homework-course-${course.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? accent : context.sfLine,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? accent : context.sfMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        StudyFlowFormat.longDay(course.day),
                        style: TextStyle(
                          color: context.sfText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          '${course.startsAt}–${course.endsAt}',
                          'Salle ${course.room}',
                          ?course.teacherName,
                        ].join(' · '),
                        style: TextStyle(color: context.sfMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (isNext)
                  ProtoChip(
                    label: 'Prochain',
                    backgroundColor: context.sfSharedSoft,
                    foregroundColor: accent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
