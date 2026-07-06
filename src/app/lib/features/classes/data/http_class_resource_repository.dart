import 'package:studyflow_app/core/network/api_client.dart';
import 'package:studyflow_app/features/classes/data/class_resource_repository.dart';
import 'package:studyflow_app/features/classes/domain/class_resource_models.dart';

class HttpClassResourceRepository implements ClassResourceRepository {
  const HttpClassResourceRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<ClassSubject>> listSubjects({String? accessToken}) async {
    final json = await _apiClient.getJsonList(
      '/api/v1/class-resources/subjects',
      accessToken: accessToken,
    );
    return json.map(ClassSubject.fromJson).toList(growable: false);
  }

  @override
  Future<ClassSubject> createSubject({
    required String name,
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/class-resources/subjects',
      body: {'name': name.trim()},
      accessToken: accessToken,
    );
    return ClassSubject.fromJson(json);
  }

  @override
  Future<void> deleteSubject({required String subjectId, String? accessToken}) {
    return _apiClient.deleteNoContent(
      '/api/v1/class-resources/subjects/$subjectId',
      accessToken: accessToken,
    );
  }

  @override
  Future<List<ClassTeacher>> listTeachers({String? accessToken}) async {
    final json = await _apiClient.getJsonList(
      '/api/v1/class-resources/teachers',
      accessToken: accessToken,
    );
    return json.map(ClassTeacher.fromJson).toList(growable: false);
  }

  @override
  Future<ClassTeacher> createTeacher({
    required String displayName,
    String? information,
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/class-resources/teachers',
      body: {
        'displayName': displayName.trim(),
        'information': information?.trim().isEmpty == true
            ? null
            : information?.trim(),
      },
      accessToken: accessToken,
    );
    return ClassTeacher.fromJson(json);
  }

  @override
  Future<void> deleteTeacher({required String teacherId, String? accessToken}) {
    return _apiClient.deleteNoContent(
      '/api/v1/class-resources/teachers/$teacherId',
      accessToken: accessToken,
    );
  }
}
