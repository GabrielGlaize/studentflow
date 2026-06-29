import 'package:studyflow_app/core/demo/demo_session_state.dart';
import 'package:studyflow_app/features/agenda/data/agenda_repository.dart';
import 'package:studyflow_app/features/agenda/domain/agenda_models.dart';

class DemoAgendaRepository implements AgendaRepository {
  const DemoAgendaRepository();

  static final List<AgendaTaskItem> _createdTasks = [];
  static final Map<String, AgendaTaskItem> _updatedTasks = {};
  static final Set<String> _deletedTaskIds = {};
  static final List<PersonalEventItem> _createdEvents = [];
  static final Map<String, PersonalEventItem> _updatedEvents = {};
  static final Set<String> _deletedEventIds = {};
  static final List<HomeworkItem> _createdHomework = [];
  static final Map<String, HomeworkItem> _updatedHomework = {};
  static final Set<String> _deletedHomeworkIds = {};

  @override
  Future<AgendaSummary> getAgenda({
    required String taskCategory,
    bool includeDone = false,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final now = DateTime.now();
    final defaultTask =
        _updatedTasks['task-1'] ??
        AgendaTaskItem(
          id: 'task-1',
          title: taskCategory == 'school'
              ? 'Relire le cours API'
              : 'Relancer une entreprise',
          description: taskCategory == 'school'
              ? 'Noter les questions pour le prochain cours.'
              : 'Envoyer un mail de suivi.',
          deadline: now.add(const Duration(hours: 5)),
          category: taskCategory,
          isDone: false,
          notificationsEnabled: true,
        );

    final tasks =
        [
              ..._createdTasks.where((task) => task.category == taskCategory),
              if (defaultTask.category == taskCategory) defaultTask,
            ]
            .where((task) {
              if (_deletedTaskIds.contains(task.id)) return false;
              if (!includeDone && task.isDone) return false;
              return true;
            })
            .toList(growable: false);
    final eventCategory = _eventCategoryFor(taskCategory);
    final defaultEvent =
        _updatedEvents['event-1'] ??
        PersonalEventItem(
          id: 'event-1',
          title: taskCategory == 'company'
              ? 'Point avec mon tuteur'
              : 'Entretien alternance',
          day: now,
          startsAt: taskCategory == 'company' ? '09:30' : '15:00',
          endsAt: taskCategory == 'company' ? '10:00' : '15:30',
          category: eventCategory,
          location: taskCategory == 'company'
              ? 'Bureau / visio'
              : 'Visio recruteur',
          notes: taskCategory == 'company'
              ? 'Faire le point sur les missions de la semaine.'
              : 'Préparer CV, portfolio et questions.',
          notificationsEnabled: true,
        );

    final events =
        [
              ..._createdEvents.where(
                (event) => event.category == eventCategory,
              ),
              if (defaultEvent.category == eventCategory) defaultEvent,
            ]
            .where((event) => !_deletedEventIds.contains(event.id))
            .toList(growable: false);

    final defaultHomework = [
      _updatedHomework['homework-1'] ??
          HomeworkItem(
            id: 'homework-1',
            title: 'Rendre le dossier d’anglais',
            description: 'Déposer le PDF sur Moodle.',
            deadline: now.add(const Duration(days: 1)),
            isDone: false,
            notificationsEnabled: true,
          ),
      _updatedHomework['homework-2'] ??
          HomeworkItem(
            id: 'homework-2',
            title: 'Préparer la présentation StudyFlow',
            deadline: now.add(const Duration(days: 3)),
            isDone: false,
            notificationsEnabled: true,
          ),
    ];

    final homework = DemoSessionState.hasNoClass(accessToken)
        ? <HomeworkItem>[]
        : [
            ..._createdHomework,
            ...defaultHomework,
          ].where((item) => !_deletedHomeworkIds.contains(item.id)).toList();

    return AgendaSummary(homework: homework, tasks: tasks, events: events);
  }

  @override
  Future<AgendaTaskItem> createTask({
    required CreateAgendaTaskRequest request,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));

    final task = AgendaTaskItem(
      id: 'demo-task-${_createdTasks.length + 2}',
      title: request.title,
      description: request.description,
      deadline: request.deadline,
      category: request.category,
      isDone: false,
      notificationsEnabled: request.notificationsEnabled,
    );
    _createdTasks.insert(0, task);
    return task;
  }

  @override
  Future<PersonalEventItem> createEvent({
    required CreatePersonalEventRequest request,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));

    final event = PersonalEventItem(
      id: 'demo-event-${_createdEvents.length + 2}',
      title: request.title.trim(),
      day: request.day,
      startsAt: request.startsAt,
      endsAt: request.endsAt,
      category: request.category,
      location: _cleanOptional(request.location),
      notes: _cleanOptional(request.notes),
      notificationsEnabled: request.notificationsEnabled,
    );
    _createdEvents.insert(0, event);
    return event;
  }

  @override
  Future<PersonalEventItem> updateEvent({
    required String eventId,
    required CreatePersonalEventRequest request,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));

    final event = PersonalEventItem(
      id: eventId,
      title: request.title.trim(),
      day: request.day,
      startsAt: request.startsAt,
      endsAt: request.endsAt,
      category: request.category,
      location: _cleanOptional(request.location),
      notes: _cleanOptional(request.notes),
      notificationsEnabled: request.notificationsEnabled,
    );
    final createdIndex = _createdEvents.indexWhere(
      (item) => item.id == eventId,
    );

    if (createdIndex == -1) {
      _updatedEvents[eventId] = event;
    } else {
      _createdEvents[createdIndex] = event;
    }

    return event;
  }

  @override
  Future<void> deleteEvent({
    required String eventId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));

    _createdEvents.removeWhere((event) => event.id == eventId);
    _updatedEvents.remove(eventId);
    _deletedEventIds.add(eventId);
  }

  @override
  Future<HomeworkItem> createHomework({
    required CreateHomeworkRequest request,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (DemoSessionState.hasNoClass(accessToken)) {
      throw StateError('Tu dois appartenir à une classe.');
    }

    final homework = HomeworkItem(
      id: 'demo-homework-${_createdHomework.length + 3}',
      title: request.title.trim(),
      description: _cleanOptional(request.description),
      deadline: request.deadline,
      courseId: request.courseId,
      isDone: false,
      notificationsEnabled: true,
    );
    _createdHomework.insert(0, homework);
    return homework;
  }

  @override
  Future<HomeworkItem> updateHomework({
    required String homeworkId,
    required CreateHomeworkRequest request,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));

    final homework = HomeworkItem(
      id: homeworkId,
      title: request.title.trim(),
      description: _cleanOptional(request.description),
      deadline: request.deadline,
      courseId: request.courseId,
      isDone: false,
      notificationsEnabled: true,
    );
    final createdIndex = _createdHomework.indexWhere(
      (item) => item.id == homeworkId,
    );

    if (createdIndex == -1) {
      _updatedHomework[homeworkId] = homework;
    } else {
      _createdHomework[createdIndex] = homework;
    }

    return homework;
  }

  @override
  Future<void> deleteHomework({
    required String homeworkId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));

    _createdHomework.removeWhere((item) => item.id == homeworkId);
    _updatedHomework.remove(homeworkId);
    _deletedHomeworkIds.add(homeworkId);
  }

  @override
  Future<AgendaTaskItem> updateTaskStatus({
    required AgendaTaskItem task,
    required bool isDone,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));

    final updatedTask = task.copyWith(isDone: isDone);
    final createdTaskIndex = _createdTasks.indexWhere(
      (item) => item.id == task.id,
    );

    if (createdTaskIndex == -1) {
      _updatedTasks[task.id] = updatedTask;
    } else {
      _createdTasks[createdTaskIndex] = updatedTask;
    }

    return updatedTask;
  }

  @override
  Future<void> deleteTask({required String taskId, String? accessToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));

    _createdTasks.removeWhere((task) => task.id == taskId);
    _updatedTasks.remove(taskId);
    _deletedTaskIds.add(taskId);
  }

  String? _cleanOptional(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  String _eventCategoryFor(String taskCategory) {
    return switch (taskCategory) {
      'company' => 'company',
      'apprenticeship' => 'apprenticeship',
      _ => 'personal',
    };
  }
}
