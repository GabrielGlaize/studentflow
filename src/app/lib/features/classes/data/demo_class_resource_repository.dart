import 'package:studyflow_app/core/demo/demo_session_state.dart';
import 'package:studyflow_app/features/classes/data/class_resource_repository.dart';
import 'package:studyflow_app/features/classes/domain/class_resource_models.dart';

class DemoClassResourceRepository implements ClassResourceRepository {
  const DemoClassResourceRepository();

  static final List<ClassSubject> _subjects = [
    const ClassSubject(id: 'subject-1', name: 'Mathématiques', isActive: true),
    const ClassSubject(id: 'subject-2', name: 'Développement', isActive: true),
    const ClassSubject(id: 'subject-3', name: 'Réseaux', isActive: true),
  ];

  static final List<ClassTeacher> _teachers = [
    const ClassTeacher(
      id: 'teacher-1',
      displayName: 'Mme Martin',
      information: 'Référente développement',
      isActive: true,
    ),
    const ClassTeacher(
      id: 'teacher-2',
      displayName: 'M. Bernard',
      information: 'Réseaux et cybersécurité',
      isActive: true,
    ),
  ];

  @override
  Future<List<ClassSubject>> listSubjects({String? accessToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (DemoSessionState.hasNoClass(accessToken)) return const [];
    return List.unmodifiable(_subjects);
  }

  @override
  Future<ClassSubject> createSubject({
    required String name,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (DemoSessionState.hasNoClass(accessToken)) {
      throw StateError('Tu dois appartenir à une classe.');
    }

    final cleanedName = name.trim();
    if (cleanedName.isEmpty) {
      throw ArgumentError('Le nom de la matière est obligatoire.');
    }

    final subject = ClassSubject(
      id: 'subject-${_subjects.length + 1}',
      name: cleanedName,
      isActive: true,
    );
    _subjects.add(subject);
    return subject;
  }

  @override
  Future<void> deleteSubject({
    required String subjectId,
    String? accessToken,
  }) async {
    _subjects.removeWhere((subject) => subject.id == subjectId);
  }

  @override
  Future<List<ClassTeacher>> listTeachers({String? accessToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (DemoSessionState.hasNoClass(accessToken)) return const [];
    return List.unmodifiable(_teachers);
  }

  @override
  Future<ClassTeacher> createTeacher({
    required String displayName,
    String? information,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (DemoSessionState.hasNoClass(accessToken)) {
      throw StateError('Tu dois appartenir à une classe.');
    }

    final cleanedName = displayName.trim();
    if (cleanedName.isEmpty) {
      throw ArgumentError('Le nom du professeur est obligatoire.');
    }

    final teacher = ClassTeacher(
      id: 'teacher-${_teachers.length + 1}',
      displayName: cleanedName,
      information: information?.trim().isEmpty == true
          ? null
          : information?.trim(),
      isActive: true,
    );
    _teachers.add(teacher);
    return teacher;
  }

  @override
  Future<void> deleteTeacher({
    required String teacherId,
    String? accessToken,
  }) async {
    _teachers.removeWhere((teacher) => teacher.id == teacherId);
  }
}
