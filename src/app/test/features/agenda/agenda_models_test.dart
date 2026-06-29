import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/agenda/domain/agenda_models.dart';

void main() {
  test('HomeworkItem.fromJson lit la réponse du backend', () {
    final homework = HomeworkItem.fromJson({
      'id': 'homework-1',
      'title': 'Rendre le dossier',
      'description': 'PDF attendu',
      'deadline': '2026-06-25T18:00:00Z',
      'courseId': 'course-1',
      'isDone': false,
      'notificationsEnabled': true,
    });

    expect(homework.title, 'Rendre le dossier');
    expect(homework.description, 'PDF attendu');
    expect(homework.notificationsEnabled, isTrue);
  });

  test('AgendaTaskItem.fromJson lit la réponse du backend', () {
    final task = AgendaTaskItem.fromJson({
      'id': 'task-1',
      'title': 'Relancer une entreprise',
      'description': 'Mail de suivi',
      'deadline': '2026-06-24T14:00:00Z',
      'category': 'apprenticeship',
      'isDone': false,
      'notificationsEnabled': true,
      'courseId': null,
    });

    expect(task.title, 'Relancer une entreprise');
    expect(task.category, 'apprenticeship');
    expect(task.deadline, isNotNull);
  });

  test('CreateHomeworkRequest écrit le JSON API', () {
    final request = CreateHomeworkRequest(
      title: ' Dossier StudyFlow ',
      description: ' Rendre le PDF ',
      deadline: DateTime.utc(2026, 6, 30, 18),
    );

    expect(request.toJson(), {
      'title': 'Dossier StudyFlow',
      'description': 'Rendre le PDF',
      'deadline': '2026-06-30T18:00:00.000Z',
      'courseId': null,
    });
  });
}
