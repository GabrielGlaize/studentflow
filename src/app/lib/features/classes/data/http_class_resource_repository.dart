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
    List<String> teacherIds = const [],
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/class-resources/subjects',
      body: {'name': name.trim(), 'teacherIds': teacherIds},
      accessToken: accessToken,
    );
    return ClassSubject.fromJson(json);
  }

  @override
  Future<ClassSubject> updateSubject({
    required String subjectId,
    required String name,
    required List<String> teacherIds,
    String? accessToken,
  }) async {
    final json = await _apiClient.putJson(
      '/api/v1/class-resources/subjects/$subjectId',
      body: {'name': name.trim(), 'teacherIds': teacherIds},
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
    List<String> subjectIds = const [],
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/class-resources/teachers',
      body: _teacherBody(displayName, information, subjectIds),
      accessToken: accessToken,
    );
    return ClassTeacher.fromJson(json);
  }

  @override
  Future<ClassTeacher> updateTeacher({
    required String teacherId,
    required String displayName,
    required List<String> subjectIds,
    String? information,
    String? accessToken,
  }) async {
    final json = await _apiClient.putJson(
      '/api/v1/class-resources/teachers/$teacherId',
      body: _teacherBody(displayName, information, subjectIds),
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

  Map<String, Object?> _teacherBody(
    String displayName,
    String? information,
    List<String> subjectIds,
  ) {
    final cleanedInformation = information?.trim();
    return {
      'displayName': displayName.trim(),
      'information': cleanedInformation == null || cleanedInformation.isEmpty
          ? null
          : cleanedInformation,
      'subjectIds': subjectIds,
    };
  }
}
