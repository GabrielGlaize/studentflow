import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/dashboard/domain/dashboard_models.dart';

void main() {
  test('DashboardSummary.fromJson lit la réponse du backend', () {
    final dashboard = DashboardSummary.fromJson({
      'generatedAt': '2026-06-24T08:00:00Z',
      'hasClass': true,
      'nextCourse': {
        'id': 'course-1',
        'subjectId': 'subject-1',
        'subjectName': 'Mathématiques',
        'teacherId': 'teacher-1',
        'teacherName': 'Mme Dupont',
        'day': '2026-06-24',
        'startsAt': '10:15:00',
        'endsAt': '12:15:00',
        'room': 'B204',
        'isCancelled': false,
        'version': 1,
      },
      'pinnedAnnouncements': [
        {
          'id': 'announcement-1',
          'content': 'Salle modifiée.',
          'authorId': 'user-1',
          'authorName': 'Délégué',
        },
      ],
      'upcomingHomework': [
        {
          'id': 'homework-1',
          'title': 'Rendre le dossier',
          'deadline': '2026-06-25T18:00:00Z',
          'isDone': false,
          'notificationsEnabled': true,
        },
      ],
      'personalTasks': [
        {
          'id': 'task-1',
          'title': 'Relancer une entreprise',
          'category': 'apprenticeship',
          'isDone': false,
          'deadline': '2026-06-24T14:00:00Z',
        },
      ],
      'todayEvents': [
        {
          'id': 'event-1',
          'title': 'Entretien',
          'day': '2026-06-24',
          'startsAt': '15:00:00',
          'endsAt': '15:30:00',
          'category': 'apprenticeship',
        },
      ],
    });

    expect(dashboard.hasClass, isTrue);
    expect(dashboard.nextCourse?.subjectName, 'Mathématiques');
    expect(dashboard.upcomingHomework.single.notificationsEnabled, isTrue);
    expect(dashboard.personalTasks.single.category, 'apprenticeship');
    expect(dashboard.todayEvents.single.title, 'Entretien');
  });
}
