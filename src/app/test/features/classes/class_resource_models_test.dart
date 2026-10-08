import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/classes/domain/class_resource_models.dart';

void main() {
  test('ClassSubject lit la reponse API', () {
    final subject = ClassSubject.fromJson({
      'id': 'subject-1',
      'name': 'Développement',
      'isActive': true,
    });

    expect(subject.id, 'subject-1');
    expect(subject.name, 'Développement');
    expect(subject.isActive, isTrue);
  });

  test('ClassTeacher lit la reponse API protegee', () {
    final teacher = ClassTeacher.fromJson({
      'id': 'teacher-1',
      'displayName': 'Mme Martin',
      'information': 'Référente Flutter',
      'isActive': true,
    });

    expect(teacher.id, 'teacher-1');
    expect(teacher.displayName, 'Mme Martin');
    expect(teacher.information, 'Référente Flutter');
    expect(teacher.isActive, isTrue);
  });

  test('les liens matière ↔ intervenant sont lus dans les deux sens', () {
    final subject = ClassSubject.fromJson({
      'id': 'subject-1',
      'name': 'Maths',
      'isActive': true,
      'teacherIds': ['teacher-1', 'teacher-2'],
    });
    final teacher = ClassTeacher.fromJson({
      'id': 'teacher-1',
      'displayName': 'M. Dupont',
      'isActive': true,
      'subjectIds': ['subject-1'],
    });

    expect(subject.teacherIds, ['teacher-1', 'teacher-2']);
    expect(teacher.subjectIds, ['subject-1']);
  });

  test('le nom d’un intervenant suit la norme « M. Nom »', () {
    expect(
      const TeacherName(
        civility: TeacherCivility.monsieur,
        lastName: 'dupont',
      ).displayName,
      'M. Dupont',
    );
    expect(
      const TeacherName(
        civility: TeacherCivility.madame,
        lastName: 'Martin',
      ).displayName,
      'Mme Martin',
    );
    expect(
      const TeacherName(
        civility: TeacherCivility.none,
        lastName: 'Équipe pédagogique',
      ).displayName,
      'Équipe pédagogique',
    );
  });

  test('un nom saisi librement retrouve sa civilité', () {
    expect(TeacherName.parse('M. Dupont').civility, TeacherCivility.monsieur);
    expect(TeacherName.parse('Monsieur Dupont').lastName, 'Dupont');
    expect(TeacherName.parse('Mme Martin').civility, TeacherCivility.madame);
    expect(TeacherName.parse('Martin').civility, TeacherCivility.none);
    // « Mme » ne doit pas être lu comme « M » suivi de « me ».
    expect(TeacherName.parse('Mme Martin').lastName, 'Martin');
  });
}
