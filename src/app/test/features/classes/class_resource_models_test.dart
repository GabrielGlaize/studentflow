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
}
