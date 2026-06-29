import 'package:studyflow_app/features/classes/domain/class_resource_models.dart';

abstract interface class ClassResourceRepository {
  Future<List<ClassSubject>> listSubjects({String? accessToken});

  Future<ClassSubject> createSubject({
    required String name,
    String? accessToken,
  });

  Future<void> deleteSubject({required String subjectId, String? accessToken});

  Future<List<ClassTeacher>> listTeachers({String? accessToken});

  Future<ClassTeacher> createTeacher({
    required String displayName,
    String? information,
    String? accessToken,
  });

  Future<void> deleteTeacher({required String teacherId, String? accessToken});
}
