import 'package:studyflow_app/core/network/api_client.dart';
import 'package:studyflow_app/features/agenda/data/agenda_repository.dart';
import 'package:studyflow_app/features/agenda/domain/agenda_models.dart';

class HttpAgendaRepository implements AgendaRepository {
  const HttpAgendaRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<AgendaSummary> getAgenda({
    required String taskCategory,
    bool includeDone = false,
    String? accessToken,
  }) async {
    final homeworkJson = await _loadHomeworkSafely(
      includeDone: includeDone,
      accessToken: accessToken,
    );
    final tasksJson = await _apiClient.getJsonList(
      '/api/v1/personal-agenda/tasks?category=$taskCategory&includeDone=$includeDone',
      accessToken: accessToken,
    );
    final eventsJson = await _apiClient.getJsonList(
      '/api/v1/personal-agenda/events?category=${_eventCategoryFor(taskCategory)}',
      accessToken: accessToken,
    );

    return AgendaSummary(
      homework: homeworkJson.map(HomeworkItem.fromJson).toList(growable: false),
      tasks: tasksJson.map(AgendaTaskItem.fromJson).toList(growable: false),
      events: eventsJson
          .map(PersonalEventItem.fromJson)
          .toList(growable: false),
    );
  }

  Future<List<Map<String, Object?>>> _loadHomeworkSafely({
    required bool includeDone,
    String? accessToken,
  }) async {
    try {
      return await _apiClient.getJsonList(
        '/api/v1/homework?includeDone=$includeDone',
        accessToken: accessToken,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 403 || error.statusCode == 404) {
        return const [];
      }
      rethrow;
    }
  }

  @override
  Future<AgendaTaskItem> createTask({
    required CreateAgendaTaskRequest request,
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/personal-agenda/tasks',
      body: request.toJson(),
      accessToken: accessToken,
    );

    return AgendaTaskItem.fromJson(json);
  }

  @override
  Future<PersonalEventItem> createEvent({
    required CreatePersonalEventRequest request,
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/personal-agenda/events',
      body: request.toJson(),
      accessToken: accessToken,
    );

    return PersonalEventItem.fromJson(json);
  }

  @override
  Future<PersonalEventItem> updateEvent({
    required String eventId,
    required CreatePersonalEventRequest request,
    String? accessToken,
  }) async {
    final json = await _apiClient.putJson(
      '/api/v1/personal-agenda/events/$eventId',
      body: request.toJson(),
      accessToken: accessToken,
    );

    return PersonalEventItem.fromJson(json);
  }

  @override
  Future<void> deleteEvent({required String eventId, String? accessToken}) {
    return _apiClient.deleteNoContent(
      '/api/v1/personal-agenda/events/$eventId',
      accessToken: accessToken,
    );
  }

  @override
  Future<HomeworkItem> createHomework({
    required CreateHomeworkRequest request,
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/homework',
      body: request.toJson(),
      accessToken: accessToken,
    );

    return HomeworkItem.fromJson(json);
  }

  @override
  Future<HomeworkItem> updateHomework({
    required String homeworkId,
    required CreateHomeworkRequest request,
    String? accessToken,
  }) async {
    final json = await _apiClient.putJson(
      '/api/v1/homework/$homeworkId',
      body: request.toJson(),
      accessToken: accessToken,
    );

    return HomeworkItem.fromJson(json);
  }

  @override
  Future<void> deleteHomework({
    required String homeworkId,
    String? accessToken,
  }) {
    return _apiClient.deleteNoContent(
      '/api/v1/homework/$homeworkId',
      accessToken: accessToken,
    );
  }

  @override
  Future<AgendaTaskItem> updateTaskStatus({
    required AgendaTaskItem task,
    required bool isDone,
    String? accessToken,
  }) async {
    final json = await _apiClient.putJson(
      '/api/v1/personal-agenda/tasks/${task.id}',
      body: task.toUpdateJson(isDone: isDone),
      accessToken: accessToken,
    );

    return AgendaTaskItem.fromJson(json);
  }

  @override
  Future<void> deleteTask({required String taskId, String? accessToken}) {
    return _apiClient.deleteNoContent(
      '/api/v1/personal-agenda/tasks/$taskId',
      accessToken: accessToken,
    );
  }

  String _eventCategoryFor(String taskCategory) {
    return switch (taskCategory) {
      'company' => 'company',
      'apprenticeship' => 'apprenticeship',
      _ => 'personal',
    };
  }
}
