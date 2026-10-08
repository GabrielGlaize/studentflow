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
    final json = await _apiClient.postJson(
      '/api/v1/courses',
      body: _courseBody(data),
      accessToken: accessToken,
    );

    return CourseItem.fromJson(json);
  }

  @override
  Future<List<CourseItem>> createCourses({
    required List<CourseFormData> courses,
    String? accessToken,
  }) async {
    final json = await _apiClient.postJsonList(
      '/api/v1/courses/batch',
      body: {'courses': courses.map(_courseBody).toList()},
      accessToken: accessToken,
    );

    return json.map(CourseItem.fromJson).toList(growable: false);
  }

  @override
  Future<CourseItem> updateCourse({
    required String courseId,
    required CourseFormData data,
    String? accessToken,
  }) async {
    final json = await _apiClient.putJson(
      '/api/v1/courses/$courseId',
      body: {..._courseBody(data), 'version': data.version ?? 1},
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

  Map<String, Object?> _courseBody(CourseFormData data) {
    return {
      'subjectId': data.subjectId,
      'teacherId': data.teacherId,
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
