import 'package:studyflow_app/core/network/api_client.dart';
import 'package:studyflow_app/features/schedule/data/course_repository.dart';
import 'package:studyflow_app/features/schedule/domain/course_models.dart';

class HttpCourseRepository implements CourseRepository {
  const HttpCourseRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<CourseItem>> listCourses({
    required DateTime from,
    required DateTime to,
    String? accessToken,
  }) async {
    final json = await _apiClient.getJsonList(
      '/api/v1/courses?from=${_dateOnly(from)}&to=${_dateOnly(to)}',
      accessToken: accessToken,
    );

    return json.map(CourseItem.fromJson).toList(growable: false);
  }

  @override
  Future<CourseItem> createCourse({
    required CourseFormData data,
    String? accessToken,
  }) async {
    final subjectId = await _resolveSubjectId(data.subjectName, accessToken);
    final teacherId = await _resolveTeacherId(data.teacherName, accessToken);

    final json = await _apiClient.postJson(
      '/api/v1/courses',
      body: _courseBody(data, subjectId: subjectId, teacherId: teacherId),
      accessToken: accessToken,
    );

    return CourseItem.fromJson(json);
  }

  @override
  Future<CourseItem> updateCourse({
    required String courseId,
    required CourseFormData data,
    String? accessToken,
  }) async {
    final subjectId = await _resolveSubjectId(data.subjectName, accessToken);
    final teacherId = await _resolveTeacherId(data.teacherName, accessToken);

    final json = await _apiClient.putJson(
      '/api/v1/courses/$courseId',
      body: {
        ..._courseBody(data, subjectId: subjectId, teacherId: teacherId),
        'version': data.version ?? 1,
      },
      accessToken: accessToken,
    );

    return CourseItem.fromJson(json);
  }

  @override
  Future<void> deleteCourse({required String courseId, String? accessToken}) {
    return _apiClient.deleteNoContent(
      '/api/v1/courses/$courseId',
      accessToken: accessToken,
    );
  }

  @override
  Future<List<CourseRevisionItem>> listCourseRevisions({
    required String courseId,
    String? accessToken,
  }) async {
    final json = await _apiClient.getJsonList(
      '/api/v1/courses/$courseId/revisions',
      accessToken: accessToken,
    );
    return json.map(CourseRevisionItem.fromJson).toList(growable: false);
  }

  @override
  Future<CourseItem> restoreLatestCourse({
    required String courseId,
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/courses/$courseId/restore-latest',
      body: const {},
      accessToken: accessToken,
    );
    return CourseItem.fromJson(json);
  }

  Future<String> _resolveSubjectId(
    String subjectName,
    String? accessToken,
  ) async {
    final cleanedName = subjectName.trim();
    final subjects = await _apiClient.getJsonList(
      '/api/v1/class-resources/subjects',
      accessToken: accessToken,
    );

    for (final subject in subjects) {
      if ((subject['name'] as String).toLowerCase() ==
          cleanedName.toLowerCase()) {
        return subject['id'] as String;
      }
    }

    final created = await _apiClient.postJson(
      '/api/v1/class-resources/subjects',
      body: {'name': cleanedName},
      accessToken: accessToken,
    );
    return created['id'] as String;
  }

  Future<String?> _resolveTeacherId(
    String? teacherName,
    String? accessToken,
  ) async {
    final cleanedName = teacherName?.trim();
    if (cleanedName == null || cleanedName.isEmpty) return null;

    final teachers = await _apiClient.getJsonList(
      '/api/v1/class-resources/teachers',
      accessToken: accessToken,
    );

    for (final teacher in teachers) {
      if ((teacher['displayName'] as String).toLowerCase() ==
          cleanedName.toLowerCase()) {
        return teacher['id'] as String;
      }
    }

    final created = await _apiClient.postJson(
      '/api/v1/class-resources/teachers',
      body: {'displayName': cleanedName, 'information': null},
      accessToken: accessToken,
    );
    return created['id'] as String;
  }

  Map<String, Object?> _courseBody(
    CourseFormData data, {
    required String subjectId,
    required String? teacherId,
  }) {
    return {
      'subjectId': subjectId,
      'teacherId': teacherId,
      'day': _dateOnly(data.day),
      'startsAt': _timeOnly(data.startsAt),
      'endsAt': _timeOnly(data.endsAt),
      'room': data.room.trim(),
      'isCancelled': data.isCancelled,
      'seriesId': null,
    };
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _timeOnly(String value) {
    final trimmed = value.trim();
    return trimmed.length == 5 ? '$trimmed:00' : trimmed;
  }
}
