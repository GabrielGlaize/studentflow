import 'package:studyflow_app/features/agenda/domain/agenda_models.dart';

abstract interface class AgendaRepository {
  Future<AgendaSummary> getAgenda({
    required String taskCategory,
    bool includeDone = false,
    String? accessToken,
  });

  Future<AgendaTaskItem> createTask({
    required CreateAgendaTaskRequest request,
    String? accessToken,
  });

  Future<PersonalEventItem> createEvent({
    required CreatePersonalEventRequest request,
    String? accessToken,
  });

  Future<PersonalEventItem> updateEvent({
    required String eventId,
    required CreatePersonalEventRequest request,
    String? accessToken,
  });

  Future<void> deleteEvent({required String eventId, String? accessToken});

  Future<HomeworkItem> createHomework({
    required CreateHomeworkRequest request,
    String? accessToken,
  });

  Future<HomeworkItem> updateHomework({
    required String homeworkId,
    required CreateHomeworkRequest request,
    String? accessToken,
  });

  Future<void> deleteHomework({
    required String homeworkId,
    String? accessToken,
  });

  Future<AgendaTaskItem> updateTaskStatus({
    required AgendaTaskItem task,
    required bool isDone,
    String? accessToken,
  });

  Future<void> deleteTask({required String taskId, String? accessToken});
}
