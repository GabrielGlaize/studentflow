import 'package:studyflow_app/core/demo/demo_session_state.dart';
import 'package:studyflow_app/features/classes/data/class_resource_repository.dart';
import 'package:studyflow_app/features/classes/domain/class_resource_models.dart';

class DemoClassResourceRepository implements ClassResourceRepository {
  const DemoClassResourceRepository();

  static final List<ClassSubject> _subjects = [
    const ClassSubject(
      id: 'subject-1',
      name: 'Mathématiques',
      isActive: true,
      teacherIds: ['teacher-2'],
    ),
    const ClassSubject(
      id: 'subject-2',
      name: 'Développement',
      isActive: true,
      teacherIds: ['teacher-1'],
    ),
    const ClassSubject(
      id: 'subject-3',
      name: 'Réseaux',
      isActive: true,
      teacherIds: ['teacher-2'],
    ),
  ];

  static final List<ClassTeacher> _teachers = [
    const ClassTeacher(
      id: 'teacher-1',
      displayName: 'Mme Martin',
      information: 'Référente développement',
      isActive: true,
      subjectIds: ['subject-2'],
    ),
    const ClassTeacher(
      id: 'teacher-2',
      displayName: 'M. Bernard',
      information: 'Réseaux et cybersécurité',
      isActive: true,
      subjectIds: ['subject-1', 'subject-3'],
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
    List<String> teacherIds = const [],
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    _ensureClass(accessToken);

    final cleanedName = _required(
      name,
      'Le nom de la matière est obligatoire.',
    );
    if (_subjects.any(
      (x) => x.name.toLowerCase() == cleanedName.toLowerCase(),
    )) {
      throw StateError(
        'La matière « $cleanedName » existe déjà dans la classe.',
      );
    }

    final subject = ClassSubject(
      id: 'subject-${DateTime.now().microsecondsSinceEpoch}',
      name: cleanedName,
      isActive: true,
      teacherIds: List.unmodifiable(teacherIds),
    );
    _subjects.add(subject);
    _syncTeachersOf(subject);
    return subject;
  }

  @override
  Future<ClassSubject> updateSubject({
    required String subjectId,
    required String name,
    required List<String> teacherIds,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    _ensureClass(accessToken);

    final index = _subjects.indexWhere((x) => x.id == subjectId);
    if (index < 0) throw StateError('Matière introuvable.');

    final subject = _subjects[index].copyWith(
      name: _required(name, 'Le nom de la matière est obligatoire.'),
      teacherIds: List.unmodifiable(teacherIds),
    );
    _subjects[index] = subject;
    _syncTeachersOf(subject);
    return subject;
  }

  @override
  Future<void> deleteSubject({
    required String subjectId,
    String? accessToken,
  }) async {
    _subjects.removeWhere((subject) => subject.id == subjectId);
    _syncTeachersOf(ClassSubject(id: subjectId, name: '', isActive: false));
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
    List<String> subjectIds = const [],
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    _ensureClass(accessToken);

    final cleanedName = _required(
      displayName,
      'Le nom de l’intervenant est obligatoire.',
    );
    final teacher = ClassTeacher(
      id: 'teacher-${DateTime.now().microsecondsSinceEpoch}',
      displayName: cleanedName,
      information: _optional(information),
      isActive: true,
      subjectIds: List.unmodifiable(subjectIds),
    );
    _teachers.add(teacher);
    _syncSubjectsOf(teacher);
    return teacher;
  }

  @override
  Future<ClassTeacher> updateTeacher({
    required String teacherId,
    required String displayName,
    required List<String> subjectIds,
    String? information,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    _ensureClass(accessToken);

    final index = _teachers.indexWhere((x) => x.id == teacherId);
    if (index < 0) throw StateError('Intervenant introuvable.');

    final teacher = ClassTeacher(
      id: teacherId,
      displayName: _required(
        displayName,
        'Le nom de l’intervenant est obligatoire.',
      ),
      information: _optional(information),
      isActive: true,
      subjectIds: List.unmodifiable(subjectIds),
    );
    _teachers[index] = teacher;
    _syncSubjectsOf(teacher);
    return teacher;
  }

  @override
  Future<void> deleteTeacher({
    required String teacherId,
    String? accessToken,
  }) async {
    _teachers.removeWhere((teacher) => teacher.id == teacherId);
    _syncSubjectsOf(
      ClassTeacher(id: teacherId, displayName: '', isActive: false),
    );
  }

  /// Garde les liens cohérents dans les deux sens, comme le fait le serveur.
  void _syncTeachersOf(ClassSubject subject) {
    for (var i = 0; i < _teachers.length; i++) {
      final teacher = _teachers[i];
      final shouldLink = subject.teacherIds.contains(teacher.id);
      final ids = {...teacher.subjectIds}
        ..remove(subject.id)
        ..addAll([if (shouldLink) subject.id]);
      _teachers[i] = teacher.copyWith(subjectIds: List.unmodifiable(ids));
    }
  }

  void _syncSubjectsOf(ClassTeacher teacher) {
    for (var i = 0; i < _subjects.length; i++) {
      final subject = _subjects[i];
      final shouldLink = teacher.subjectIds.contains(subject.id);
      final ids = {...subject.teacherIds}
        ..remove(teacher.id)
        ..addAll([if (shouldLink) teacher.id]);
      _subjects[i] = subject.copyWith(teacherIds: List.unmodifiable(ids));
    }
  }

  void _ensureClass(String? accessToken) {
    if (DemoSessionState.hasNoClass(accessToken)) {
      throw StateError('Tu dois appartenir à une classe.');
    }
  }

  String _required(String value, String message) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) throw ArgumentError(message);
    return cleaned;
  }

  String? _optional(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
