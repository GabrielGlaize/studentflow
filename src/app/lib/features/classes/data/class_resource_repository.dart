import 'package:studyflow_app/features/classes/domain/class_resource_models.dart';

abstract interface class ClassResourceRepository {
  Future<List<ClassSubject>> listSubjects({String? accessToken});

  Future<ClassSubject> createSubject({
    required String name,
    List<String> teacherIds = const [],
    String? accessToken,
  });

  Future<ClassSubject> updateSubject({
    required String subjectId,
    required String name,
    required List<String> teacherIds,
    String? accessToken,
  });

  Future<void> deleteSubject({required String subjectId, String? accessToken});

  Future<List<ClassTeacher>> listTeachers({String? accessToken});

  Future<ClassTeacher> createTeacher({
    required String displayName,
    String? information,
    List<String> subjectIds = const [],
    String? accessToken,
  });

  Future<ClassTeacher> updateTeacher({
    required String teacherId,
    required String displayName,
    required List<String> subjectIds,
    String? information,
    String? accessToken,
  });

  Future<void> deleteTeacher({required String teacherId, String? accessToken});
}
